sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.refreshBtn = m.top.findNode("refreshBtn")
    m.grid = m.top.findNode("grid")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.spinner = m.top.findNode("spinner")

    m.items = []
    m.focusZone = "grid"
    m.gridContent = createObject("roSGNode", "ContentNode")
    m.grid.content = m.gridContent
    m.loaded = false

    m.refreshBtn.observeField("selected", "onRefreshButton")
    m.grid.observeField("itemSelected", "onGridSelected")
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    if m.loaded = true then return
    loadWatchlist()
end sub

sub onRefresh()
    if m.top.refresh <> true then return
    m.top.refresh = false
    loadWatchlist()
end sub

sub onRefocus()
    if m.top.refocus <> true then return
    m.top.refocus = false
    if m.items.count() > 0 then
        focusGrid()
    else
        m.refreshBtn.setFocus(true)
        m.focusZone = "toolbar"
    end if
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

sub onRefreshButton()
    loadWatchlist()
end sub

sub loadWatchlist()
    m.top.loadingMessage = "Loading Watchlist…"
    m.metaLabel.text = "Loading your Plex Watchlist…"
    setBusy(true)
    clearGrid()
    showEmpty("")

    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "watchlist"
    m.task.item = { filter: "all" }
    m.task.observeField("response", "onWatchlistLoaded")
    m.task.control = "RUN"
end sub

sub onWatchlistLoaded()
    setBusy(false)
    m.top.loadingMessage = ""
    m.loaded = true
    response = m.task.response
    if response = invalid or response.ok <> true then
        err = "Couldn't load Watchlist"
        if response <> invalid and response.error <> invalid then err = asString(response.error)
        showEmpty(err + " — check your Plex token in PlexConfig.brs")
        m.metaLabel.text = err
        m.refreshBtn.setFocus(true)
        m.focusZone = "toolbar"
        return
    end if

    m.items = response.items
    if m.items = invalid then m.items = []
    paintGrid()

    if m.items.count() = 0 then
        showEmpty("Your Plex Watchlist is empty. Search for a title and add it from the detail page.")
        m.metaLabel.text = "0 titles"
        m.refreshBtn.setFocus(true)
        m.focusZone = "toolbar"
    else
        m.emptyLabel.visible = false
        m.metaLabel.text = asString(m.items.count()) + " titles · same list as the official Plex apps"
        focusGrid()
    end if
end sub

sub clearGrid()
    while m.gridContent.getChildCount() > 0
        m.gridContent.removeChildIndex(0)
    end while
end sub

sub paintGrid()
    clearGrid()
    for each item in m.items
        child = m.gridContent.createChild("ContentNode")
        nodeTitle = asString(item.title)
        child.title = nodeTitle
        child.hdPosterUrl = asString(item.hdPosterUrl)
        child.description = asString(item.description)
        child.addFields({
            ratingKey: asString(item.ratingKey),
            discoverRatingKey: asString(item.discoverRatingKey),
            guid: asString(item.guid),
            key: asString(item.key),
            mediaType: asString(item.mediaType),
            year: asString(item.year),
            rating: asString(item.rating),
            contentRating: asString(item.contentRating),
            hdBackdropUrl: asString(item.hdBackdropUrl),
            isDiscover: true,
            unavailable: true,
            onWatchlist: true,
            watched: item.watched = true,
            unwatchedCount: 0,
            viewOffset: 0
        })
    end for
    m.grid.content = m.gridContent
end sub

sub onGridSelected()
    idx = m.grid.itemSelected
    if idx = invalid or idx < 0 or idx >= m.items.count() then return
    m.top.selectedItem = m.items[idx]
end sub

sub showEmpty(message as String)
    if message = "" then
        m.emptyLabel.visible = false
        m.emptyLabel.text = ""
        return
    end if
    m.emptyLabel.text = message
    m.emptyLabel.visible = true
end sub

sub setBusy(busy as Boolean)
    if m.spinner <> invalid then
        m.spinner.visible = busy
        if busy then m.spinner.control = "start" else m.spinner.control = "stop"
    end if
end sub

sub focusGrid()
    if m.items.count() = 0 then
        m.refreshBtn.setFocus(true)
        m.focusZone = "toolbar"
        return
    end if
    m.focusZone = "grid"
    m.grid.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.openMenu = true
        return true
    end if

    if key = "left" then
        if m.focusZone = "toolbar" then
            m.top.openMenu = true
            return true
        end if
        col = 0
        if m.grid.itemFocused <> invalid then col = m.grid.itemFocused MOD 6
        if col = 0 then
            m.top.openMenu = true
            return true
        end if
        return false
    end if

    if m.focusZone = "grid" and key = "up" then
        ' Jump to Refresh when focus is already on the top row — MarkupGrid keeps up otherwise
        return false
    end if

    if key = "options" or key = "replay" then
        loadWatchlist()
        return true
    end if

    return false
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
