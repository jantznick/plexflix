sub init()
    m.loadingPanel = m.top.findNode("loadingPanel")
    m.frame = m.top.findNode("frame")
    m.billboard = m.top.findNode("billboard")
    m.heroArt = m.top.findNode("heroArt")
    m.heroCopy = m.top.findNode("heroCopy")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroMeta = m.top.findNode("heroMeta")
    m.heroSummary = m.top.findNode("heroSummary")
    m.rowList = m.top.findNode("rowList")
    m.rowsClip = m.top.findNode("rowsClip")
    m.peekStrip = m.top.findNode("peekStrip")
    m.peekPosters = m.top.findNode("peekPosters")
    m.homeAnim = m.top.findNode("homeAnim")
    m.billboardMove = m.top.findNode("billboardMove")
    m.billboardFade = m.top.findNode("billboardFade")
    m.rowsMove = m.top.findNode("rowsMove")

    ' Active shelf is ALWAYS the RowList focus slot — never the peek strip.
    ' rowsClip clips away RowList's native previous-row peek (which was aligned + moved).
    m.expandedRowY = 720
    m.collapsedRowY = 130
    m.rowsX = 96
    m.heroHideY = -920
    m.isCollapsed = false
    m.currentRow = -1
    m.tileStep = 172

    if m.heroArt <> invalid then
        m.heroArt.loadDisplayMode = "scaleToZoom"
        m.heroArt.loadWidth = 1920
        m.heroArt.loadHeight = 1080
        m.heroArt.width = 1920
        m.heroArt.height = 900
        m.heroArt.translation = [0, 0]
    end if

    m.splashMosaic = m.top.findNode("splashMosaic")
    if m.splashMosaic <> invalid then m.splashMosaic.active = true

    m.snapTimer = createObject("roSGNode", "Timer")
    m.snapTimer.repeat = false
    m.snapTimer.duration = 0.18
    m.snapTimer.observeField("fire", "onAnimSnap")

    m.rowList.observeField("rowItemSelected", "onRowItemSelected")
    m.rowList.observeField("rowItemFocused", "onRowItemFocused")
    m.rowList.observeField("escapeLeft", "onEscapeLeft")
    m.rowList.observeField("escapeUp", "onEscapeUp")

    m.focusPoll = createObject("roSGNode", "Timer")
    m.focusPoll.repeat = true
    m.focusPoll.duration = 0.15
    m.focusPoll.observeField("fire", "onFocusPoll")
    m.focusPoll.control = "start"

    hidePeek()
    m.top.observeField("config", "onConfigReady")
    m.top.setFocus(true)
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    if m.splashMosaic <> invalid then
        m.splashMosaic.active = true
        splashUrl = ""
        if m.top.config.splashManifestUrl <> invalid then splashUrl = m.top.config.splashManifestUrl
        if splashUrl <> "" then m.splashMosaic.manifestUrl = splashUrl
    end if
    loadHome()
end sub

sub hideSplash()
    if m.splashMosaic <> invalid then m.splashMosaic.active = false
end sub

sub loadHome()
    m.top.loadingMessage = "Connecting to Plex..."
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "home"
    m.task.observeField("response", "onHomeLoaded")
    m.task.control = "RUN"
end sub

sub onHomeLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    hideSplash()

    if response = invalid or response.ok <> true then
        err = "Could not reach Plex. Check baseUrl/token in roku/source/PlexConfig.brs"
        if response <> invalid and response.error <> invalid and response.error <> "" then
            err = response.error
        end if
        if m.loadingPanel <> invalid then m.loadingPanel.visible = false
        if m.frame <> invalid then m.frame.visible = true
        m.heroTitle.text = "Unable to load library"
        m.heroSummary.text = err
        return
    end if

    content = response.content
    if content = invalid or content.getChildCount() = 0 then
        if m.loadingPanel <> invalid then m.loadingPanel.visible = false
        if m.frame <> invalid then m.frame.visible = true
        m.heroTitle.text = "No media found"
        m.heroSummary.text = "Your Plex server responded, but no movie/TV hubs were returned."
        return
    end if

    if m.loadingPanel <> invalid then m.loadingPanel.visible = false
    if m.frame <> invalid then m.frame.visible = true

    m.rowList.content = content
    m.currentRow = -1
    setBrowseMode(false)
    m.rowList.setFocus(true)

    firstRow = content.getChild(0)
    if firstRow <> invalid and firstRow.getChildCount() > 0 then
        updateHeroContent(firstRow.getChild(0))
    end if
end sub

sub onFocusPoll()
    applyFocusedRow(false)
end sub

sub onRowItemFocused()
    applyFocusedRow(true)
end sub

sub applyFocusedRow(force as Boolean)
    info = m.rowList.rowItemFocused
    if info = invalid or info.count() < 2 then return

    rowIndex = info[0]
    colIndex = info[1]
    rowChanged = (rowIndex <> m.currentRow)
    if not force and not rowChanged then return

    row = m.rowList.content.getChild(rowIndex)
    if row = invalid then return
    item = row.getChild(colIndex)
    if item = invalid then return

    m.currentRow = rowIndex
    if rowChanged then
        setBrowseMode(rowIndex > 0)
        updatePeek(rowIndex)
    end if
    updateHeroContent(item)
end sub

sub hidePeek()
    if m.peekStrip <> invalid then m.peekStrip.visible = false
    clearPeekPosters()
end sub

sub clearPeekPosters()
    if m.peekPosters = invalid then return
    while m.peekPosters.getChildCount() > 0
        m.peekPosters.removeChildIndex(0)
    end while
end sub

sub updatePeek(rowIndex as Integer)
    ' Peek = previous shelf only. Never focusable.
    if rowIndex < 1 or m.isCollapsed <> true then
        hidePeek()
        return
    end if

    prev = m.rowList.content.getChild(rowIndex - 1)
    if prev = invalid then
        hidePeek()
        return
    end if

    clearPeekPosters()

    ' Opposite of the focused row's half-tile stagger so peek never shares columns.
    ' Even focused (x=0) → peek at -86; odd focused (x=-86) → peek at 0
    stagger = -86
    if (rowIndex MOD 2) = 1 then stagger = 0

    maxN = 10
    drawn = 0
    x = stagger
    for i = 0 to prev.getChildCount() - 1
        if drawn >= maxN then exit for
        it = prev.getChild(i)
        if it <> invalid and it.isSpacer <> true then
            p = createObject("roSGNode", "Poster")
            p.width = 150
            p.height = 225
            p.loadDisplayMode = "scaleToZoom"
            p.loadWidth = 300
            p.loadHeight = 450
            p.opacity = 0.55
            uri = ""
            if it.hdPosterUrl <> invalid then uri = it.hdPosterUrl
            if uri <> "" then p.uri = uri else p.uri = "pkg:/images/poster_placeholder.png"
            p.translation = [x, 0]
            m.peekPosters.appendChild(p)
            x = x + m.tileStep
            drawn = drawn + 1
        end if
    end for

    m.peekRow = rowIndex
    m.peekStrip.visible = true
end sub

sub setBrowseMode(collapsed as Boolean)
    if collapsed then
        m.pendingHero = [0, m.heroHideY]
        m.pendingRows = [0, m.collapsedRowY]
        m.pendingOpacity = 0.0
    else
        m.pendingHero = [0, 0]
        m.pendingRows = [0, m.expandedRowY]
        m.pendingOpacity = 1.0
        hidePeek()
    end if

    m.isCollapsed = collapsed
    applyBrowseModeSnap()
end sub

sub onAnimSnap()
    applyBrowseModeSnap()
end sub

sub applyBrowseModeSnap()
    if m.pendingHero = invalid then return
    if m.homeAnim <> invalid then m.homeAnim.control = "stop"
    m.billboard.translation = m.pendingHero
    if m.rowsClip <> invalid then
        m.rowsClip.translation = m.pendingRows
    else
        m.rowList.translation = [m.rowsX, m.pendingRows[1]]
    end if
    m.billboard.opacity = m.pendingOpacity
    if m.isCollapsed then
        m.billboard.visible = false
        m.heroCopy.visible = false
    else
        m.billboard.visible = true
        m.heroCopy.visible = true
        m.billboard.opacity = 1.0
        hidePeek()
    end if
end sub

sub updateHeroContent(item as Object)
    if m.heroArt <> invalid then
        m.heroArt.loadDisplayMode = "scaleToZoom"
        m.heroArt.loadWidth = 1920
        m.heroArt.loadHeight = 1080
        m.heroArt.width = 1920
        m.heroArt.height = 900
        m.heroArt.translation = [0, 0]
    end if

    uri = ""
    if item.hdBackdropUrl <> invalid and item.hdBackdropUrl <> "" then
        uri = item.hdBackdropUrl
    else if item.hdShowPosterUrl <> invalid and item.hdShowPosterUrl <> "" then
        uri = item.hdShowPosterUrl
    else if item.hdPosterUrl <> invalid then
        uri = item.hdPosterUrl
    end if
    if uri <> "" then m.heroArt.uri = uri

    m.heroTitle.text = asString(item.title)

    metaBits = []
    year = asString(item.year)
    if year <> "" then metaBits.push(year)
    contentRating = asString(item.contentRating)
    if contentRating <> "" then metaBits.push(contentRating)
    rating = asString(item.rating)
    if rating <> "" then metaBits.push(rating + " ★")
    mediaType = asString(item.mediaType)
    if mediaType <> "" then metaBits.push(titleCaseType(mediaType))
    m.heroMeta.text = joinStrings(metaBits, "  ·  ")
    m.heroSummary.text = asString(item.description)
end sub

function titleCaseType(mediaType as String) as String
    if mediaType = "movie" then return "Movie"
    if mediaType = "show" then return "Series"
    if mediaType = "episode" then return "Episode"
    if mediaType = "season" then return "Season"
    if Len(mediaType) = 0 then return ""
    return UCase(Left(mediaType, 1)) + Right(mediaType, Len(mediaType) - 1)
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        return Str(value).Trim()
    end if
    return ""
end function

function safeToStr(value as Dynamic) as String
    return asString(value)
end function

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function

sub onRowItemSelected()
    info = m.rowList.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.rowList.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return

    m.top.selectedItem = {
        title: item.title,
        description: item.description,
        year: item.year,
        rating: item.rating,
        contentRating: item.contentRating,
        mediaType: item.mediaType,
        ratingKey: item.ratingKey,
        key: item.key,
        hdPosterUrl: item.hdPosterUrl,
        hdBackdropUrl: item.hdBackdropUrl,
        duration: item.duration,
        viewOffset: item.viewOffset,
        leafCount: item.leafCount,
        childCount: item.childCount,
        grandparentRatingKey: item.grandparentRatingKey,
        parentRatingKey: item.parentRatingKey,
        grandparentTitle: item.grandparentTitle,
        index: item.index,
        shortTitle: item.shortTitle,
        parentIndex: item.parentIndex,
        isDiscover: item.isDiscover
    }
end sub

sub onEscapeLeft()
    m.top.openMenu = true
end sub

sub onEscapeUp()
    if m.isCollapsed then
        setBrowseMode(false)
        hidePeek()
        if m.rowList.content <> invalid and m.rowList.content.getChildCount() > 0 then
            m.rowList.jumpToRowItem = [0, 0]
        end if
    end if
end sub

sub onRefocus()
    if m.top.refocus = true then
        m.rowList.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "left" then
        m.top.openMenu = true
        return true
    end if
    return false
end function
