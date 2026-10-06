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
    m.homeAnim = m.top.findNode("homeAnim")
    m.billboardMove = m.top.findNode("billboardMove")
    m.billboardFade = m.top.findNode("billboardFade")
    m.rowsMove = m.top.findNode("rowsMove")

    ' Shelves use floatingFocus, so the shelves above and below the focused one
    ' are really on screen; Up and Down move the highlight between them and only
    ' scroll once it would leave the visible rows. (No manual peek strip.)
    ' expandedRowY matches the 680px landscape billboard.
    m.expandedRowY = 560
    m.collapsedRowY = 130
    m.rowsX = 96
    m.heroHideY = -700
    m.isCollapsed = false
    m.currentRow = -1

    if m.heroArt <> invalid then
        m.heroArt.loadDisplayMode = "scaleToZoom"
        m.heroArt.loadWidth = 1920
        m.heroArt.loadHeight = 1080
        m.heroArt.width = 1920
        m.heroArt.height = 680
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
    m.rowList.observeField("escapeBack", "onEscapeBack")

    m.focusPoll = createObject("roSGNode", "Timer")
    m.focusPoll.repeat = true
    m.focusPoll.duration = 0.15
    m.focusPoll.observeField("fire", "onFocusPoll")
    m.focusPoll.control = "start"

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
    m.top.splashActive = false
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
    if m.top.suspended <> true then m.rowList.setFocus(true)

    firstRow = content.getChild(0)
    if firstRow <> invalid and firstRow.getChildCount() > 0 then
        updateHeroContent(firstRow.getChild(0))
    end if
end sub

'--------------------------------------------------------------------
' Parking and background refresh
'--------------------------------------------------------------------

sub onSuspendedChange()
    if m.top.suspended = true then
        m.focusPoll.control = "stop"
    else
        m.focusPoll.control = "start"
    end if
end sub

sub onRefresh()
    if m.top.refresh <> true or m.top.config = invalid then return
    ' The first load is still running, or a refresh already is
    if m.rowList.content = invalid or m.refreshTask <> invalid then return

    m.refreshTask = createObject("roSGNode", "PlexTask")
    m.refreshTask.config = m.top.config
    m.refreshTask.action = "home"
    m.refreshTask.observeField("response", "onRefreshLoaded")
    m.refreshTask.control = "RUN"
end sub

' Swap in fresh hubs without disturbing the viewer: rows whose items are
' unchanged are left alone, so their posters neither flicker nor reload
sub onRefreshLoaded()
    response = m.refreshTask.response
    m.refreshTask = invalid
    ' A failed refresh keeps what is on screen rather than replacing it with an error
    if response = invalid or response.ok <> true then return
    fresh = response.content
    if fresh = invalid or fresh.getChildCount() = 0 then return

    current = m.rowList.content
    if current = invalid then return

    if sameRowLayout(current, fresh) then
        for i = 0 to fresh.getChildCount() - 1
            oldRow = current.getChild(i)
            newRow = fresh.getChild(i)
            if rowSignature(oldRow) <> rowSignature(newRow) then replaceRowItems(oldRow, newRow)
        end for
    else
        ' Rows came or went (Continue Watching emptied, a new hub): swap the
        ' whole list but put the highlight back as close as possible
        info = m.rowList.rowItemFocused
        rowIndex = 0
        colIndex = 0
        if info <> invalid and info.count() >= 2 then
            rowIndex = info[0]
            colIndex = info[1]
        end if
        m.rowList.content = fresh
        if rowIndex > fresh.getChildCount() - 1 then rowIndex = fresh.getChildCount() - 1
        count = fresh.getChild(rowIndex).getChildCount()
        if colIndex > count - 1 then colIndex = count - 1
        if colIndex < 0 then colIndex = 0
        m.rowList.jumpToRowItem = [rowIndex, colIndex]
        m.currentRow = -1
    end if
    applyFocusedRow(true)
end sub

function sameRowLayout(a as Object, b as Object) as Boolean
    if a.getChildCount() <> b.getChildCount() then return false
    for i = 0 to a.getChildCount() - 1
        if asString(a.getChild(i).title) <> asString(b.getChild(i).title) then return false
    end for
    return true
end function

' Enough to notice a new episode, a moved resume point or a watched flag
function rowSignature(row as Object) as String
    parts = ""
    for i = 0 to row.getChildCount() - 1
        item = row.getChild(i)
        watched = "0"
        flag = item.watched
        if (type(flag) = "Boolean" or type(flag) = "roBoolean") and flag then watched = "1"
        parts = parts + asString(item.ratingKey) + ":" + asString(item.viewOffset) + ":" + watched + ":" + asString(item.unwatchedCount) + "|"
    end for
    return parts
end function

sub replaceRowItems(target as Object, source as Object)
    items = []
    for i = 0 to source.getChildCount() - 1
        items.push(source.getChild(i))
    end for
    ' A node has one parent, so they leave the fresh tree before joining this one
    source.removeChildrenIndex(source.getChildCount(), 0)
    target.removeChildrenIndex(target.getChildCount(), 0)
    target.appendChildren(items)
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
    if rowChanged then setBrowseMode(rowIndex > 0)
    updateHeroContent(item)
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
    end if
end sub

sub updateHeroContent(item as Object)
    ' Match DetailScreen: landscape backdrop only. Never use a portrait poster here.
    if m.heroArt <> invalid then
        m.heroArt.loadDisplayMode = "scaleToZoom"
        m.heroArt.loadWidth = 1920
        m.heroArt.loadHeight = 1080
        m.heroArt.width = 1920
        m.heroArt.height = 680
        m.heroArt.translation = [0, 0]
    end if

    uri = ""
    if item.hdBackdropUrl <> invalid and item.hdBackdropUrl <> "" then
        uri = item.hdBackdropUrl
    else if item.hdBackgroundImageUrl <> invalid and item.hdBackgroundImageUrl <> "" then
        uri = item.hdBackgroundImageUrl
    end if
    if m.heroArt <> invalid and uri <> "" then m.heroArt.uri = uri

    mediaType = asString(item.mediaType)
    isEpisode = (mediaType = "episode")

    ' Home billboard always presents show/movie level copy. Episode synopses
    ' are reserved for the detail page when an episode tile is focused.
    headline = asString(item.title)
    summary = asString(item.description)
    metaTypeLabel = titleCaseType(mediaType)
    if isEpisode then
        showName = asString(item.grandparentTitle)
        if showName = "" then showName = asString(item.shortTitle)
        if showName <> "" then headline = showName
        showSummary = ""
        if item.showDescription <> invalid then showSummary = asString(item.showDescription)
        summary = showSummary
        metaTypeLabel = "Series"
    end if

    m.heroTitle.text = headline

    metaBits = []
    year = asString(item.year)
    if year <> "" then metaBits.push(year)
    contentRating = asString(item.contentRating)
    if contentRating <> "" then metaBits.push(contentRating)
    rating = asString(item.rating)
    if rating <> "" then metaBits.push(rating + " ★")
    if metaTypeLabel <> "" then metaBits.push(metaTypeLabel)
    m.heroMeta.text = joinStrings(metaBits, "  ·  ")
    m.heroSummary.text = summary
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
        watched: item.watched,
        unwatchedCount: item.unwatchedCount,
        viewedLeafCount: item.viewedLeafCount,
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

' Back from deep in the shelves returns to the top first; from the top it
' opens the menu, which is where Back leaves the channel
sub onEscapeBack()
    if m.isCollapsed then
        onEscapeUp()
    else
        m.top.openMenu = true
    end if
end sub

sub onEscapeUp()
    if m.isCollapsed then
        setBrowseMode(false)
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
