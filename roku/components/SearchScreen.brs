sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.searchBtn = m.top.findNode("searchBtn")
    m.typeBtn = m.top.findNode("typeBtn")
    m.clearBtn = m.top.findNode("clearBtn")
    m.grid = m.top.findNode("grid")
    m.emptyLabel = m.top.findNode("emptyLabel")
    m.spinner = m.top.findNode("spinner")

    m.items = []
    m.query = ""
    m.searchTypes = "movies,tv"
    m.typeIndex = 0
    m.typeOptions = [
        { label: "All", value: "movies,tv" },
        { label: "Movies", value: "movies" },
        { label: "TV Shows", value: "tv" }
    ]
    m.focusZone = "toolbar"
    m.toolbarBtn = "search"
    m.searchDialog = invalid
    m.gridContent = createObject("roSGNode", "ContentNode")
    m.grid.content = m.gridContent

    m.searchBtn.observeField("selected", "onSearchButton")
    m.typeBtn.observeField("selected", "onTypeButton")
    m.clearBtn.observeField("selected", "onClearButton")
    m.grid.observeField("itemSelected", "onGridSelected")

    paintTypeButton()
    showEmpty("Search Plex Discover for any movie or show — open a result to add it to your Watchlist.")
    m.searchBtn.setFocus(true)
end sub

sub onConfigReady()
    ' Ready for typed searches; keyboard opens on demand
end sub

sub onRefocus()
    if m.top.refocus <> true then return
    m.top.refocus = false
    if m.items.count() > 0 then
        focusGrid()
    else
        focusToolbar("search")
    end if
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

sub paintTypeButton()
    opt = m.typeOptions[m.typeIndex]
    m.searchTypes = opt.value
    m.typeBtn.text = opt.label
end sub

sub onSearchButton()
    m.toolbarBtn = "search"
    openSearchKeyboard()
end sub

sub onTypeButton()
    m.toolbarBtn = "type"
    m.typeIndex = m.typeIndex + 1
    if m.typeIndex >= m.typeOptions.count() then m.typeIndex = 0
    paintTypeButton()
    if m.query <> "" then runSearch(m.query)
end sub

sub onClearButton()
    m.toolbarBtn = "clear"
    m.query = ""
    m.items = []
    clearGrid()
    showEmpty("Search Plex Discover for any movie or show — open a result to add it to your Watchlist.")
    m.metaLabel.text = "Find any movie or show — even ones not in your library"
    focusToolbar("search")
end sub

sub openSearchKeyboard()
    scene = m.top.getScene()
    if scene = invalid then return

    dialog = createObject("roSGNode", "KeyboardDialog")
    dialog.title = "Search movies & shows"
    dialog.text = m.query
    if m.query = "" then
        dialog.buttons = ["Search", "Cancel"]
    else
        dialog.buttons = ["Search", "Clear", "Cancel"]
    end if
    dialog.observeField("buttonSelected", "onSearchDialogButton")
    dialog.observeField("wasClosed", "onSearchClosed")
    m.searchDialog = dialog
    scene.dialog = dialog
end sub

sub onSearchDialogButton()
    dialog = m.searchDialog
    if dialog = invalid then return

    idx = dialog.buttonSelected
    typed = asString(dialog.text).Trim()
    buttons = dialog.buttons
    picked = ""
    if buttons <> invalid and idx <> invalid and idx >= 0 and idx < buttons.count() then picked = buttons[idx]

    m.searchDialog = invalid
    dialog.close = true

    if picked = "Search" then
        if typed = "" then
            showEmpty("Type a title to search Plex Discover.")
        else
            runSearch(typed)
        end if
    else if picked = "Clear" then
        onClearButton()
    end if
end sub

sub onSearchClosed()
    scene = m.top.getScene()
    if scene <> invalid and scene.dialog <> invalid then scene.dialog = invalid
    m.searchDialog = invalid
    if m.items.count() > 0 then
        focusGrid()
    else
        focusToolbar(m.toolbarBtn)
    end if
end sub

sub runSearch(query as String)
    m.query = query
    m.metaLabel.text = "Searching Discover for “" + query + "”…"
    m.top.loadingMessage = "Searching Discover…"
    setBusy(true)
    clearGrid()
    showEmpty("")

    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "discoverSearch"
    m.task.item = {
        query: query,
        searchTypes: m.searchTypes,
        limit: "48"
    }
    m.task.observeField("response", "onSearchLoaded")
    m.task.control = "RUN"
end sub

sub onSearchLoaded()
    setBusy(false)
    m.top.loadingMessage = ""
    response = m.task.response
    if response = invalid or response.ok <> true then
        err = "Search failed"
        if response <> invalid and response.error <> invalid then err = asString(response.error)
        showEmpty(err)
        m.metaLabel.text = err
        focusToolbar("search")
        return
    end if

    m.items = response.items
    if m.items = invalid then m.items = []
    paintGrid()
    if m.items.count() = 0 then
        showEmpty("No Discover matches for “" + m.query + "”. Try another title.")
        m.metaLabel.text = "0 results"
        focusToolbar("search")
    else
        m.emptyLabel.visible = false
        m.metaLabel.text = asString(m.items.count()) + " results for “" + m.query + "” · OK to open · add to Watchlist from the detail page"
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
        applyItemToNode(child, item)
    end for
    m.grid.content = m.gridContent
end sub

sub applyItemToNode(node as Object, item as Object)
    node.title = asString(item.title)
    node.hdPosterUrl = asString(item.hdPosterUrl)
    node.description = asString(item.description)
    node.addFields({
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
        onWatchlist: item.onWatchlist = true,
        watched: item.watched = true,
        unwatchedCount: 0,
        viewOffset: 0
    })
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

sub focusToolbar(which as String)
    m.focusZone = "toolbar"
    m.toolbarBtn = which
    btn = m.searchBtn
    if which = "type" then
        btn = m.typeBtn
    else if which = "clear" then
        btn = m.clearBtn
    end if
    btn.setFocus(true)
end sub

sub focusGrid()
    if m.items.count() = 0 then
        focusToolbar("search")
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

    if key = "left" and m.focusZone = "toolbar" and m.toolbarBtn = "search" then
        m.top.openMenu = true
        return true
    end if

    if m.focusZone = "toolbar" then
        if key = "right" or key = "left" then
            order = ["search", "type", "clear"]
            idx = 0
            for i = 0 to order.count() - 1
                if order[i] = m.toolbarBtn then idx = i
            end for
            if key = "right" then
                idx = idx + 1
                if idx >= order.count() then idx = order.count() - 1
            else
                idx = idx - 1
                if idx < 0 then
                    m.top.openMenu = true
                    return true
                end if
            end if
            focusToolbar(order[idx])
            return true
        else if key = "down" then
            if m.items.count() > 0 then
                focusGrid()
                return true
            end if
            return true
        else if key = "options" or key = "replay" then
            openSearchKeyboard()
            return true
        end if
    else if m.focusZone = "grid" then
        if key = "up" then
            ' Let MarkupGrid consume up until the top row; escape via an empty press path is awkward,
            ' so Left from column 0 also returns to the toolbar.
            return false
        else if key = "left" then
            ' Opening the menu from the first column matches other browse screens
            col = 0
            if m.grid.itemFocused <> invalid then col = m.grid.itemFocused MOD 6
            if col = 0 then
                m.top.openMenu = true
                return true
            end if
            return false
        end if
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
    if valueType = "Boolean" or valueType = "roBoolean" then
        if value = true then return "true"
        return "false"
    end if
    return ""
end function
