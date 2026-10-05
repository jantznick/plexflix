' Full-library grid: one scrolling MarkupGrid over a sliding window of Plex pages.
'
' Only MAXWINDOWPAGES * PAGESIZE content nodes are ever live, so a 10,000 title
' library costs the same memory as a 300 title one. Paging is driven by the
' focused index: cross into the last rows and the next Plex page is appended,
' scroll back toward the top and the previous page is prepended again.

sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.posLabel = m.top.findNode("posLabel")
    m.grid = m.top.findNode("grid")
    m.spinner = m.top.findNode("spinner")
    m.emptyLabel = m.top.findNode("emptyLabel")

    m.filterBg = m.top.findNode("filterBg")
    m.filterLabel = m.top.findNode("filterLabel")
    m.searchBg = m.top.findNode("searchBg")
    m.searchLabel = m.top.findNode("searchLabel")
    m.sortBg = m.top.findNode("sortBg")
    m.sortLabel = m.top.findNode("sortLabel")

    m.filterPanel = m.top.findNode("filterPanel")
    m.filterList = m.top.findNode("filterList")
    m.panelTitle = m.top.findNode("panelTitle")
    m.panelHint = m.top.findNode("panelHint")

    m.numColumns = 11
    m.pageSize = 66          ' six grid rows per Plex request
    m.maxWindowPages = 5     ' hard cap on live content nodes (5 * 66 = 330)
    m.prefetchRows = 2

    m.libraryTitle = "Library"
    m.sectionId = ""
    m.sectionType = ""
    m.genres = []

    m.activeGenre = "All"
    m.activeGenreId = ""
    m.activeDecade = "All"
    m.activeSearch = ""
    m.activeSort = "titleSort"
    m.unwatchedOnly = false

    m.windowStart = 0
    m.totalSize = 0
    m.hasMoreForward = false
    m.loading = false
    m.pendingDir = ""
    m.requestSeq = 0
    m.activeRequestId = ""
    m.lastFocusRow = -1
    m.deferInitialLoad = false
    m.warning = ""

    m.task = invalid
    m.prevTask = invalid
    m.searchDialog = invalid

    m.toolbarButtons = ["filter", "search", "sort"]
    m.toolbarBtn = "filter"
    m.focusZone = "grid"
    m.filterMode = ""
    m.panelEntry = ""

    m.sortOptions = [
        { key: "titleSort", label: "Title A–Z" },
        { key: "titleSort:desc", label: "Title Z–A" },
        { key: "addedAt:desc", label: "Recently added" },
        { key: "year:desc", label: "Year — newest" },
        { key: "year", label: "Year — oldest" },
        { key: "rating:desc", label: "Rating — highest" },
        { key: "lastViewedAt:desc", label: "Recently watched" }
    ]

    m.gridRoot = createObject("roSGNode", "ContentNode")
    m.grid.content = m.gridRoot

    m.grid.observeField("itemSelected", "onGridSelected")
    m.grid.observeField("itemFocused", "onGridFocused")
    m.filterList.observeField("itemSelected", "onFilterSelected")

    paintToolbar()
end sub

'--------------------------------------------------------------------
' Source / lifecycle
'--------------------------------------------------------------------

sub onSourceSet()
    source = m.top.source
    if source = invalid then return

    m.libraryTitle = asString(source.title)
    if m.libraryTitle = "" then m.libraryTitle = "Library"
    m.titleLabel.text = m.libraryTitle

    m.sectionId = asString(source.sectionId)
    if m.sectionId = "" then m.sectionId = asString(source.ratingKey)
    m.sectionType = asString(source.sectionType)

    m.genres = source.genres
    if m.genres = invalid then m.genres = []

    m.activeGenre = "All"
    m.activeGenreId = ""
    m.activeDecade = "All"
    m.activeSearch = asString(source.search)
    m.activeSort = "titleSort"
    m.unwatchedOnly = false

    if source.openSearch = true then
        ' Opened straight from the library Search button — ask first, fetch once
        m.deferInitialLoad = true
        refreshStatus()
        openSearchKeyboard()
    else
        applyFilters()
    end if
end sub

sub onRefocus()
    if m.top.refocus <> true then return
    if m.filterPanel.visible = true then
        m.filterList.setFocus(true)
    else if gridCount() > 0 then
        focusGrid()
    else
        focusToolbar(m.toolbarBtn)
    end if
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

'--------------------------------------------------------------------
' Paging
'--------------------------------------------------------------------

function gridCount() as Integer
    if m.gridRoot = invalid then return 0
    return m.gridRoot.getChildCount()
end function

function windowEnd() as Integer
    return m.windowStart + gridCount()
end function

function currentFocusIndex() as Integer
    idx = m.grid.itemFocused
    if idx = invalid or idx < 0 then return 0
    if idx > gridCount() - 1 then return gridCount() - 1
    return idx
end function

sub applyFilters()
    ' Any in-flight page is abandoned; stale responses are dropped by requestId
    m.loading = false
    m.lastFocusRow = -1
    m.deferInitialLoad = false
    loadPage("reset")
end sub

sub loadPage(direction as String)
    if m.sectionId = "" then
        showEmpty("This library is missing its Plex section id.")
        focusToolbar("filter")
        return
    end if

    startAt = 0
    size = m.pageSize
    if direction = "forward" then
        if m.loading then return
        if m.hasMoreForward <> true then return
        startAt = windowEnd()
        if m.totalSize > 0 and startAt >= m.totalSize then return
    else if direction = "back" then
        if m.loading then return
        if m.windowStart <= 0 then return
        startAt = m.windowStart - m.pageSize
        if startAt < 0 then startAt = 0
        ' Ask for exactly the gap so the prepended page can't overlap the window
        size = m.windowStart - startAt
    else
        direction = "reset"
    end if

    m.requestSeq = m.requestSeq + 1
    m.activeRequestId = StrI(m.requestSeq).Trim()
    m.pendingDir = direction
    m.loading = true

    if direction = "reset" then
        hideEmpty()
        setSpinner(true)
        m.top.loadingMessage = "Loading " + m.libraryTitle + "…"
    end if
    refreshStatus()

    payload = {
        title: m.libraryTitle,
        sectionId: m.sectionId,
        sectionType: m.sectionType,
        genre: m.activeGenre,
        genreId: m.activeGenreId,
        decade: m.activeDecade,
        search: m.activeSearch,
        sort: m.activeSort,
        unwatched: m.unwatchedOnly,
        start: startAt,
        pageSize: size,
        requestId: m.activeRequestId
    }

    m.prevTask = m.task
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "sectionAll"
    m.task.item = payload
    m.task.observeField("response", "onLoaded")
    m.task.control = "RUN"
end sub

sub onLoaded(event as Object)
    response = event.getData()
    if response = invalid then return
    if asString(response.requestId) <> m.activeRequestId then return ' superseded

    direction = m.pendingDir
    if direction = "" then direction = "reset"
    m.pendingDir = ""
    m.loading = false
    setSpinner(false)
    m.top.loadingMessage = ""

    if response.ok <> true then
        err = "Could not load titles"
        if asString(response.error) <> "" then err = asString(response.error)
        if direction = "reset" then
            resetGrid([])
            showEmpty(err)
            focusToolbar("filter")
        else
            ' Keep what is already on screen and stop paging that way
            if direction = "forward" then m.hasMoreForward = false
        end if
        refreshStatus()
        return
    end if

    if response.totalSize <> invalid and response.totalSize > 0 then m.totalSize = response.totalSize
    if direction = "reset" then m.warning = asString(response.warning)

    newNodes = []
    page = response.content
    if page <> invalid and page.getChildCount() > 0 then
        newNodes = page.getChildren(-1, 0)
        page.removeChildren(newNodes)
    end if

    if direction = "reset" then
        m.hasMoreForward = (response.hasMore = true)
        resetGrid(newNodes)
        if gridCount() = 0 then
            showEmpty(emptyMessage())
            focusToolbar("filter")
            refreshStatus()
            return
        end if
        hideEmpty()
        m.lastFocusRow = 0
        focusGrid()
    else if direction = "forward" then
        m.hasMoreForward = (response.hasMore = true)
        if newNodes.count() > 0 then
            m.gridRoot.appendChildren(newNodes)
            trimWindowFront()
        end if
    else
        if newNodes.count() > 0 then
            focused = currentFocusIndex()
            m.gridRoot.insertChildren(newNodes, 0)
            m.windowStart = m.windowStart - newNodes.count()
            if m.windowStart < 0 then m.windowStart = 0
            m.grid.jumpToItem = focused + newNodes.count()
            trimWindowBack()
        end if
    end if

    refreshStatus()
end sub

sub resetGrid(nodes as Object)
    m.gridRoot = createObject("roSGNode", "ContentNode")
    if nodes <> invalid and nodes.count() > 0 then m.gridRoot.appendChildren(nodes)
    m.grid.content = m.gridRoot
    m.windowStart = 0
    if gridCount() > 0 then m.grid.jumpToItem = 0
end sub

sub trimWindowFront()
    cap = m.pageSize * m.maxWindowPages
    count = gridCount()
    if count <= cap then return
    drop = wholeRows(count - cap)
    if drop <= 0 then return

    focused = currentFocusIndex()
    m.gridRoot.removeChildrenIndex(drop, 0)
    m.windowStart = m.windowStart + drop
    newFocus = focused - drop
    if newFocus < 0 then newFocus = 0
    m.grid.jumpToItem = newFocus
end sub

sub trimWindowBack()
    cap = m.pageSize * m.maxWindowPages
    count = gridCount()
    if count <= cap then return
    drop = wholeRows(count - cap)
    if drop <= 0 then return

    m.gridRoot.removeChildrenIndex(drop, count - drop)
    ' We just gave the tail back, so there is definitely more to fetch forward
    m.hasMoreForward = true
end sub

function wholeRows(value as Integer) as Integer
    ' Trim in whole grid rows so the focused poster keeps its column
    if value <= 0 then return 0
    return Int(value / m.numColumns) * m.numColumns
end function

'--------------------------------------------------------------------
' Grid events
'--------------------------------------------------------------------

sub onGridFocused()
    idx = m.grid.itemFocused
    if idx = invalid or idx < 0 then return
    count = gridCount()
    if count = 0 then return

    row = Int(idx / m.numColumns)
    if row <> m.lastFocusRow then
        m.lastFocusRow = row
        refreshStatus()
    end if

    edge = m.numColumns * m.prefetchRows
    if idx >= count - edge then
        loadPage("forward")
    else if m.windowStart > 0 and idx <= edge then
        loadPage("back")
    end if
end sub

sub onGridSelected()
    idx = m.grid.itemSelected
    if idx = invalid or idx < 0 then return
    if m.gridRoot = invalid or idx > gridCount() - 1 then return
    item = m.gridRoot.getChild(idx)
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
        shortTitle: item.shortTitle
    }
end sub

'--------------------------------------------------------------------
' Header / status
'--------------------------------------------------------------------

sub setSpinner(on as Boolean)
    if m.spinner = invalid then return
    if on then
        m.spinner.visible = true
        m.spinner.control = "start"
    else
        m.spinner.control = "stop"
        m.spinner.visible = false
    end if
end sub

sub showEmpty(message as String)
    if m.emptyLabel = invalid then return
    m.emptyLabel.text = message
    m.emptyLabel.visible = true
end sub

sub hideEmpty()
    if m.emptyLabel = invalid then return
    m.emptyLabel.visible = false
end sub

function emptyMessage() as String
    if activeFilterCount() = 0 then return "This library looks empty."
    return "Nothing matches " + filterSummary() + "." + Chr(10) + "Open Filter to clear it."
end function

function activeFilterCount() as Integer
    count = 0
    if m.activeGenre <> "" and m.activeGenre <> "All" then count = count + 1
    if m.activeDecade <> "" and m.activeDecade <> "All" then count = count + 1
    if m.unwatchedOnly then count = count + 1
    if m.activeSearch <> "" then count = count + 1
    return count
end function

function filterSummary() as String
    bits = []
    if m.activeGenre <> "" and m.activeGenre <> "All" then bits.push(m.activeGenre)
    if m.activeDecade <> "" and m.activeDecade <> "All" then bits.push(m.activeDecade + "s")
    if m.unwatchedOnly then bits.push("Unwatched only")
    if m.activeSearch <> "" then bits.push("“" + m.activeSearch + "”")
    if bits.count() = 0 then return "All titles"
    return joinBits(bits, "  ·  ")
end function

function positionText() as String
    if m.deferInitialLoad then return ""
    count = gridCount()
    if count = 0 then
        if m.loading then return "Loading…"
        return ""
    end if

    total = m.totalSize
    if total <= 0 then total = windowEnd()
    out = formatCount(m.windowStart + currentFocusIndex() + 1) + " of " + formatCount(total)
    if m.loading then out = out + "  ·  loading…"
    return out
end function

sub refreshStatus()
    if m.metaLabel <> invalid then
        summary = filterSummary()
        if m.warning <> "" then summary = summary + "  ·  " + m.warning
        m.metaLabel.text = summary
    end if
    if m.posLabel <> invalid then m.posLabel.text = positionText()
    if m.sortLabel <> invalid then m.sortLabel.text = "Order by: " + sortLabelFor(m.activeSort)
    if m.filterLabel <> invalid then
        count = activeFilterCount()
        if count > 0 then
            m.filterLabel.text = "Filter (" + StrI(count).Trim() + ")"
        else
            m.filterLabel.text = "Filter"
        end if
    end if
end sub

'--------------------------------------------------------------------
' Focus
'--------------------------------------------------------------------

sub focusGrid()
    if gridCount() = 0 then
        focusToolbar(m.toolbarBtn)
        return
    end if
    m.focusZone = "grid"
    paintToolbar()
    m.grid.setFocus(true)
end sub

sub focusToolbar(which as String)
    m.focusZone = "toolbar"
    if which <> "" then m.toolbarBtn = which
    paintToolbar()
    m.top.setFocus(true)
end sub

sub paintToolbar()
    active = ""
    if m.focusZone = "toolbar" then active = m.toolbarBtn
    paintButton(m.filterBg, m.filterLabel, active = "filter")
    paintButton(m.searchBg, m.searchLabel, active = "search")
    paintButton(m.sortBg, m.sortLabel, active = "sort")
end sub

sub paintButton(bg as Object, label as Object, focused as Boolean)
    if bg = invalid then return
    if focused then
        bg.color = "0xFFFFFF"
        if label <> invalid then label.color = "0x111118"
    else
        bg.color = "0x2A2A32"
        if label <> invalid then label.color = "0xFFFFFF"
    end if
end sub

sub moveToolbar(delta as Integer)
    idx = 0
    for i = 0 to m.toolbarButtons.count() - 1
        if m.toolbarButtons[i] = m.toolbarBtn then idx = i
    end for
    idx = idx + delta
    if idx < 0 then idx = 0
    if idx > m.toolbarButtons.count() - 1 then idx = m.toolbarButtons.count() - 1
    m.toolbarBtn = m.toolbarButtons[idx]
    paintToolbar()
end sub

sub activateToolbarButton()
    if m.toolbarBtn = "search" then
        openSearchKeyboard()
    else if m.toolbarBtn = "sort" then
        openFilterPanel("sort")
    else
        openFilterPanel("filter")
    end if
end sub

'--------------------------------------------------------------------
' Filter / sort panel
'--------------------------------------------------------------------

sub openFilterPanel(mode as String)
    m.panelEntry = mode
    showPanelMode(mode)
    m.filterPanel.visible = true
    m.focusZone = "panel"
    paintToolbar()
    m.filterList.setFocus(true)
end sub

sub closeFilterPanel()
    m.filterPanel.visible = false
    m.filterMode = ""
    if gridCount() > 0 then
        focusGrid()
    else
        focusToolbar(m.toolbarBtn)
    end if
end sub

sub showPanelMode(mode as String)
    m.filterMode = mode
    if mode = "sort" then
        m.panelTitle.text = "Order by"
        m.panelHint.text = "Sorting reloads the grid from the top"
        buildSortList()
    else if mode = "genre" then
        m.panelTitle.text = "Genre"
        m.panelHint.text = genreHint()
        buildGenreList()
    else if mode = "decade" then
        m.panelTitle.text = "Decade"
        m.panelHint.text = "Release decade"
        buildDecadeList()
    else
        m.panelTitle.text = "Filter"
        m.panelHint.text = filterSummary()
        buildFilterRoot()
    end if
end sub

function genreHint() as String
    if m.genres = invalid or m.genres.count() = 0 then return "No genres reported by this library"
    return StrI(m.genres.count()).Trim() + " genres in " + m.libraryTitle
end function

sub buildFilterRoot()
    root = createObject("roSGNode", "ContentNode")
    addFilterItem(root, "Genre: " + displayValue(m.activeGenre, "All"), "openGenre", "", "")
    addFilterItem(root, "Decade: " + decadeDisplay(), "openDecade", "", "")
    addFilterItem(root, "Unwatched only: " + onOff(m.unwatchedOnly), "toggleUnwatched", "", "")
    addFilterItem(root, "Order by: " + sortLabelFor(m.activeSort), "openSort", "", "")
    if m.activeSearch <> "" then
        addFilterItem(root, "Search: “" + m.activeSearch + "” (change)", "openSearch", "", "")
    else
        addFilterItem(root, "Search titles…", "openSearch", "", "")
    end if
    if activeFilterCount() > 0 then
        addFilterItem(root, "Clear all filters", "clearAll", "", "")
    end if
    addFilterItem(root, "Done", "done", "", "")
    setPanelContent(root)
end sub

sub buildSortList()
    root = createObject("roSGNode", "ContentNode")
    for each option in m.sortOptions
        addFilterItem(root, check(option.key = m.activeSort) + option.label, "setSort", option.key, option.label)
    end for
    addFilterItem(root, "← Back", "back", "", "")
    setPanelContent(root)
end sub

sub buildGenreList()
    root = createObject("roSGNode", "ContentNode")
    addFilterItem(root, check(m.activeGenre = "All") + "All genres", "setGenre", "", "All")
    if m.genres <> invalid then
        for each g in m.genres
            label = asString(g.title)
            if label = "" then label = asString(g.tag)
            id = asString(g.id)
            if id = "" then id = asString(g.key)
            if label <> "" and label <> "All" then
                addFilterItem(root, check(label = m.activeGenre) + label, "setGenre", id, label)
            end if
        end for
    end if
    addFilterItem(root, "← Back", "back", "", "")
    setPanelContent(root)
end sub

sub buildDecadeList()
    root = createObject("roSGNode", "ContentNode")
    addFilterItem(root, check(m.activeDecade = "All") + "All years", "setDecade", "All", "All")
    decades = ["2020", "2010", "2000", "1990", "1980", "1970", "1960", "1950"]
    for each d in decades
        addFilterItem(root, check(d = m.activeDecade) + d + "s", "setDecade", d, d)
    end for
    addFilterItem(root, "← Back", "back", "", "")
    setPanelContent(root)
end sub

sub setPanelContent(root as Object)
    m.filterList.content = root
    m.filterList.jumpToItem = 0
end sub

sub addFilterItem(root as Object, display as String, action as String, value as String, label as String)
    child = root.createChild("ContentNode")
    child.title = display
    child.addFields({ action: action, value: value, label: label })
end sub

function check(isActive as Boolean) as String
    if isActive then return "✓  "
    return "     "
end function

function onOff(flag as Boolean) as String
    if flag then return "On"
    return "Off"
end function

function displayValue(value as String, fallback as String) as String
    if value = "" then return fallback
    return value
end function

function decadeDisplay() as String
    if m.activeDecade = "" or m.activeDecade = "All" then return "All"
    return m.activeDecade + "s"
end function

function sortLabelFor(sortKey as String) as String
    for each option in m.sortOptions
        if option.key = sortKey then return option.label
    end for
    return "Title A–Z"
end function

sub onFilterSelected()
    idx = m.filterList.itemSelected
    if idx = invalid or idx < 0 then return
    if m.filterList.content = invalid then return
    row = m.filterList.content.getChild(idx)
    if row = invalid then return

    action = asString(row.action)
    value = asString(row.value)
    label = asString(row.label)

    if action = "openGenre" then
        showPanelMode("genre")
    else if action = "openDecade" then
        showPanelMode("decade")
    else if action = "openSort" then
        showPanelMode("sort")
    else if action = "openSearch" then
        m.filterPanel.visible = false
        m.filterMode = ""
        openSearchKeyboard()
    else if action = "toggleUnwatched" then
        m.unwatchedOnly = not m.unwatchedOnly
        closeFilterPanel()
        applyFilters()
    else if action = "setGenre" then
        m.activeGenre = label
        m.activeGenreId = value
        if label = "All" then m.activeGenreId = ""
        closeFilterPanel()
        applyFilters()
    else if action = "setDecade" then
        m.activeDecade = value
        closeFilterPanel()
        applyFilters()
    else if action = "setSort" then
        m.activeSort = value
        closeFilterPanel()
        applyFilters()
    else if action = "clearAll" then
        m.activeGenre = "All"
        m.activeGenreId = ""
        m.activeDecade = "All"
        m.activeSearch = ""
        m.unwatchedOnly = false
        closeFilterPanel()
        applyFilters()
    else if action = "back" then
        showPanelMode(m.panelEntry)
    else
        closeFilterPanel()
    end if
end sub

'--------------------------------------------------------------------
' Search keyboard
'--------------------------------------------------------------------

sub openSearchKeyboard()
    scene = m.top.getScene()
    if scene = invalid then return

    dialog = createObject("roSGNode", "KeyboardDialog")
    dialog.title = "Search " + m.libraryTitle
    dialog.text = m.activeSearch
    if m.activeSearch = "" then
        dialog.buttons = ["Search", "Cancel"]
    else
        dialog.buttons = ["Search", "Clear search", "Cancel"]
    end if
    dialog.observeField("buttonSelected", "onSearchButton")
    dialog.observeField("wasClosed", "onSearchClosed")
    m.searchDialog = dialog
    scene.dialog = dialog
end sub

sub onSearchButton()
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
        m.activeSearch = typed
        applyFilters()
    else if picked = "Clear search" then
        m.activeSearch = ""
        applyFilters()
    else if m.deferInitialLoad then
        ' Cancelled before the first fetch — fall back to the unfiltered grid
        applyFilters()
    end if
end sub

sub onSearchClosed()
    ' Drop the scene's reference too, otherwise MainScene keeps treating the remote as busy
    scene = m.top.getScene()
    if scene <> invalid and scene.dialog <> invalid then scene.dialog = invalid

    if m.searchDialog <> invalid then
        ' Backed out of the keyboard without choosing a button
        m.searchDialog = invalid
        if m.deferInitialLoad then
            applyFilters()
            return
        end if
    end if
    if m.loading then return
    if gridCount() > 0 then
        focusGrid()
    else
        focusToolbar(m.toolbarBtn)
    end if
end sub

'--------------------------------------------------------------------
' Keys
'--------------------------------------------------------------------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.filterPanel.visible = true then
        if key = "back" then
            if m.filterMode <> m.panelEntry then
                showPanelMode(m.panelEntry)
            else
                closeFilterPanel()
            end if
            return true
        end if
        ' Never let left/right leak out to the sidebar while the panel is up
        if key = "left" or key = "right" then return true
        return false
    end if

    if key = "back" then
        m.top.closed = true
        return true
    end if

    if key = "options" then
        openFilterPanel("filter")
        return true
    end if

    if m.focusZone = "toolbar" then
        if key = "left" then
            if m.toolbarBtn = m.toolbarButtons[0] then
                m.top.openMenu = true
            else
                moveToolbar(-1)
            end if
        else if key = "right" then
            moveToolbar(1)
        else if key = "down" then
            focusGrid()
        else if key = "OK" or key = "play" then
            activateToolbarButton()
        end if
        return true
    end if

    ' Grid zone: the grid itself handles movement and only bubbles at its edges
    if key = "up" then
        focusToolbar(m.toolbarBtn)
        return true
    else if key = "left" then
        m.top.openMenu = true
        return true
    end if

    return false
end function

'--------------------------------------------------------------------
' Helpers
'--------------------------------------------------------------------

function joinBits(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function

function formatCount(value as Integer) as String
    digits = StrI(value).Trim()
    if Len(digits) < 4 then return digits
    out = ""
    placed = 0
    for i = Len(digits) to 1 step -1
        out = Mid(digits, i, 1) + out
        placed = placed + 1
        if placed mod 3 = 0 and i > 1 then out = "," + out
    end for
    return out
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
