sub init()
    m.billboard = m.top.findNode("billboard")
    m.heroArt = m.top.findNode("heroArt")
    m.heroCopy = m.top.findNode("heroCopy")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroMeta = m.top.findNode("heroMeta")
    m.heroSummary = m.top.findNode("heroSummary")
    m.rowList = m.top.findNode("rowList")
    m.buildLabel = m.top.findNode("buildLabel")

    ' Expanded = billboard mode. Collapsed = shelves fill the screen.
    m.expandedRowY = 560
    m.collapsedRowY = 88
    m.heroHideY = -700
    m.isCollapsed = false
    m.currentRow = -1

    m.rowList.observeField("rowItemSelected", "onRowItemSelected")
    m.rowList.observeField("rowItemFocused", "onRowItemFocused")

    ' brs-desktop sometimes misses rowItemFocused; poll as a backup
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
    loadHome()
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

    if response = invalid or response.ok <> true then
        err = "Could not reach Plex. Check baseUrl/token in roku/source/PlexConfig.brs"
        if response <> invalid and response.error <> invalid and response.error <> "" then
            err = response.error
        end if
        m.heroTitle.text = "Unable to load library"
        m.heroSummary.text = err
        return
    end if

    content = response.content
    if content = invalid or content.getChildCount() = 0 then
        m.heroTitle.text = "No media found"
        m.heroSummary.text = "Your Plex server responded, but no movie/TV hubs were returned."
        return
    end if

    rowCount = content.getChildCount()
    m.buildLabel.text = "v0.2.0 · " + rowCount.toStr() + " rows"

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
    if not force and rowIndex = m.currentRow then return

    row = m.rowList.content.getChild(rowIndex)
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return

    m.currentRow = rowIndex
    ' Any shelf below the first one hides the billboard and lifts the rails
    setBrowseMode(rowIndex > 0)
    updateHeroContent(item)
end sub

sub setBrowseMode(collapsed as Boolean)
    ' IMPORTANT: set properties directly. SceneGraph Animation is unreliable in brs-desktop.
    if collapsed then
        m.billboard.translation = [0, m.heroHideY]
        m.billboard.opacity = 0.0
        m.billboard.visible = false
        m.heroCopy.visible = false
        m.rowList.translation = [0, m.collapsedRowY]
    else
        m.billboard.visible = true
        m.billboard.opacity = 1.0
        m.billboard.translation = [0, 0]
        m.heroCopy.visible = true
        m.rowList.translation = [0, m.expandedRowY]
    end if
    m.isCollapsed = collapsed
end sub

sub updateHeroContent(item as Object)
    if item.hdBackdropUrl <> invalid and item.hdBackdropUrl <> "" then
        m.heroArt.uri = item.hdBackdropUrl
    else if item.hdPosterUrl <> invalid then
        m.heroArt.uri = item.hdPosterUrl
    end if

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
    return value.toStr()
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
        childCount: item.childCount
    }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "OK" and not m.rowList.hasFocus() then
        m.rowList.setFocus(true)
        return true
    end if

    ' Extra insurance if RowList swallows focus events in the simulator
    if key = "down" or key = "up" then
        applyFocusedRow(true)
    end if

    return false
end function
