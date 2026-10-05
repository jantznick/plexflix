sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.grid = m.top.findNode("grid")
    m.spinner = m.top.findNode("spinner")
    m.filterBg = m.top.findNode("filterBg")
    m.searchBg = m.top.findNode("searchBg")
    m.filterLabel = m.top.findNode("filterLabel")
    m.searchLabel = m.top.findNode("searchLabel")
    m.filterPanel = m.top.findNode("filterPanel")
    m.filterList = m.top.findNode("filterList")

    m.sectionId = ""
    m.genres = []
    m.activeGenre = "All"
    m.activeSearch = ""
    m.activeSort = "titleSort"
    m.activeDecade = "All"
    m.nextStart = 0
    m.hasMore = false
    m.loadingMore = false
    m.pageSize = 66
    m.gridRoot = invalid
    m.focusZone = "grid" ' grid | toolbar | filter
    m.toolbarBtn = "filter"
    m.filterMode = "root" ' root | genre | sort | decade

    m.grid.observeField("itemSelected", "onGridSelected")
    m.grid.observeField("itemFocused", "onGridFocused")
    m.filterList.observeField("itemSelected", "onFilterSelected")
end sub

sub onSourceSet()
    source = m.top.source
    if source = invalid then return
    title = asString(source.title)
    if title <> "" then m.titleLabel.text = title + " · All"
    m.sectionId = asString(source.sectionId)
    m.genres = source.genres
    if m.genres = invalid then m.genres = []
    m.activeSearch = asString(source.search)
    m.activeGenre = "All"
    m.activeSort = "titleSort"
    m.activeDecade = "All"
    m.nextStart = 0
    m.gridRoot = createObject("roSGNode", "ContentNode")
    m.grid.content = m.gridRoot
    loadPage(true)
end sub

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

sub loadPage(reset as Boolean)
    if reset then
        m.nextStart = 0
        m.gridRoot = createObject("roSGNode", "ContentNode")
        m.grid.content = m.gridRoot
        m.grid.visible = false
        setSpinner(true)
        m.top.loadingMessage = "Loading titles…"
    else
        if m.loadingMore or m.hasMore <> true then return
        m.loadingMore = true
        m.metaLabel.text = buildMetaLine() + "  ·  Loading more…"
    end if

    payload = {
        title: asString(m.top.source.title),
        sectionId: m.sectionId,
        genre: m.activeGenre,
        search: m.activeSearch,
        sort: m.activeSort,
        decade: m.activeDecade,
        start: m.nextStart,
        pageSize: m.pageSize
    }

    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "sectionAll"
    m.task.item = payload
    m.task.observeField("response", "onLoaded")
    m.task.control = "RUN"
end sub

function buildMetaLine() as String
    bits = []
    if m.activeGenre <> "" and m.activeGenre <> "All" then bits.push(m.activeGenre)
    if m.activeDecade <> "" and m.activeDecade <> "All" then bits.push(m.activeDecade + "s")
    if m.activeSort = "addedAt:desc" then bits.push("Recently added")
    if m.activeSort = "rating:desc" then bits.push("Top rated")
    if m.activeSort = "year:desc" then bits.push("Newest year")
    if m.activeSearch <> "" then bits.push("Search: " + m.activeSearch)
    if bits.count() = 0 then return "A–Z"
    return joinBits(bits, "  ·  ")
end function

sub onLoaded()
    setSpinner(false)
    m.top.loadingMessage = ""
    m.loadingMore = false

    response = m.task.response
    if response = invalid or response.ok <> true then
        err = "Could not load titles"
        if response <> invalid and response.error <> invalid then err = response.error
        m.metaLabel.text = err
        return
    end if

    page = response.content
    if page = invalid then page = createObject("roSGNode", "ContentNode")
    for i = 0 to page.getChildCount() - 1
        node = page.getChild(i)
        if node <> invalid then m.gridRoot.appendChild(node)
    end for

    m.hasMore = (response.hasMore = true)
    if response.nextStart <> invalid then m.nextStart = response.nextStart

    shown = m.gridRoot.getChildCount()
    total = 0
    if response.totalSize <> invalid then total = response.totalSize
    meta = buildMetaLine() + "  ·  " + StrI(shown).Trim()
    if total > 0 then meta = meta + " of " + StrI(total).Trim()
    if m.hasMore then meta = meta + "  ·  more below"
    m.metaLabel.text = meta

    if shown = 0 then
        m.metaLabel.text = "No titles match this filter"
        return
    end if

    m.grid.visible = true
    if m.focusZone = "grid" then m.grid.setFocus(true)
end sub

sub onGridFocused()
    idx = m.grid.itemFocused
    if idx = invalid then return
    ' Prefetch next page near the end
    total = 0
    if m.gridRoot <> invalid then total = m.gridRoot.getChildCount()
    if total > 0 and idx >= total - 12 then
        loadPage(false)
    end if
end sub

sub onGridSelected()
    idx = m.grid.itemSelected
    if idx = invalid or idx < 0 then return
    item = m.grid.content.getChild(idx)
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

sub openFilterPanel()
    m.filterMode = "root"
    buildFilterRoot()
    m.filterPanel.visible = true
    m.focusZone = "filter"
    m.filterList.setFocus(true)
end sub

sub closeFilterPanel()
    m.filterPanel.visible = false
    m.focusZone = "grid"
    m.grid.setFocus(true)
    paintToolbar("")
end sub

sub buildFilterRoot()
    root = createObject("roSGNode", "ContentNode")
    addFilterItem(root, "Sort: " + sortLabel(m.activeSort), "sort")
    addFilterItem(root, "Genre: " + m.activeGenre, "genre")
    addFilterItem(root, "Decade: " + m.activeDecade, "decade")
    addFilterItem(root, "Search…", "search")
    addFilterItem(root, "Clear all filters", "clear")
    addFilterItem(root, "Done", "done")
    m.filterList.content = root
    m.filterList.jumpToItem = 0
end sub

sub buildSortList()
    root = createObject("roSGNode", "ContentNode")
    addFilterItem(root, "Title A–Z", "titleSort")
    addFilterItem(root, "Recently added", "addedAt:desc")
    addFilterItem(root, "Top rated", "rating:desc")
    addFilterItem(root, "Newest year", "year:desc")
    addFilterItem(root, "← Back", "back")
    m.filterList.content = root
    m.filterList.jumpToItem = 0
end sub

sub buildGenreList()
    root = createObject("roSGNode", "ContentNode")
    addFilterItem(root, "All genres", "All")
    if m.genres <> invalid then
        maxG = m.genres.count()
        if maxG > 40 then maxG = 40
        for i = 0 to maxG - 1
            g = m.genres[i]
            tag = asString(g.tag)
            title = asString(g.title)
            if title = "" then title = tag
            if title <> "" and title <> "All" then addFilterItem(root, title, title)
        end for
    end if
    addFilterItem(root, "← Back", "back")
    m.filterList.content = root
    m.filterList.jumpToItem = 0
end sub

sub buildDecadeList()
    root = createObject("roSGNode", "ContentNode")
    addFilterItem(root, "All years", "All")
    decades = ["2020", "2010", "2000", "1990", "1980", "1970", "1960", "1950"]
    for each d in decades
        addFilterItem(root, d + "s", d)
    end for
    addFilterItem(root, "← Back", "back")
    m.filterList.content = root
    m.filterList.jumpToItem = 0
end sub

sub addFilterItem(root as Object, title as String, action as String)
    child = root.createChild("ContentNode")
    child.title = title
    child.addFields({ action: action })
end sub

function sortLabel(sortKey as String) as String
    if sortKey = "addedAt:desc" then return "Recently added"
    if sortKey = "rating:desc" then return "Top rated"
    if sortKey = "year:desc" then return "Newest year"
    return "Title A–Z"
end function

sub onFilterSelected()
    idx = m.filterList.itemSelected
    if idx = invalid or idx < 0 then return
    row = m.filterList.content.getChild(idx)
    if row = invalid then return
    action = asString(row.action)

    if m.filterMode = "root" then
        if action = "sort" then
            m.filterMode = "sort"
            buildSortList()
        else if action = "genre" then
            m.filterMode = "genre"
            buildGenreList()
        else if action = "decade" then
            m.filterMode = "decade"
            buildDecadeList()
        else if action = "search" then
            closeFilterPanel()
            runSearch()
        else if action = "clear" then
            m.activeGenre = "All"
            m.activeSearch = ""
            m.activeSort = "titleSort"
            m.activeDecade = "All"
            closeFilterPanel()
            loadPage(true)
        else if action = "done" then
            closeFilterPanel()
        end if
    else if m.filterMode = "sort" then
        if action = "back" then
            m.filterMode = "root"
            buildFilterRoot()
        else
            m.activeSort = action
            closeFilterPanel()
            loadPage(true)
        end if
    else if m.filterMode = "genre" then
        if action = "back" then
            m.filterMode = "root"
            buildFilterRoot()
        else
            m.activeGenre = action
            closeFilterPanel()
            loadPage(true)
        end if
    else if m.filterMode = "decade" then
        if action = "back" then
            m.filterMode = "root"
            buildFilterRoot()
        else
            m.activeDecade = action
            closeFilterPanel()
            loadPage(true)
        end if
    end if
end sub

sub runSearch()
    m.searchTask = createObject("roSGNode", "SearchKeyboardTask")
    m.searchTask.prompt = "Search " + m.titleLabel.text
    m.searchTask.initialText = m.activeSearch
    m.searchTask.observeField("result", "onSearchDone")
    m.searchTask.control = "RUN"
end sub

sub onSearchDone()
    if m.searchTask.cancelled = true then
        m.focusZone = "grid"
        m.grid.setFocus(true)
        return
    end if
    m.activeSearch = asString(m.searchTask.result)
    loadPage(true)
end sub

sub paintToolbar(which as String)
    m.toolbarBtn = which
    if which = "filter" then
        m.filterBg.color = "0xFFFFFF"
        m.searchBg.color = "0x2A2A32"
        if m.filterLabel <> invalid then m.filterLabel.color = "0x111118"
        if m.searchLabel <> invalid then m.searchLabel.color = "0xFFFFFF"
    else if which = "search" then
        m.filterBg.color = "0x2A2A32"
        m.searchBg.color = "0xFFFFFF"
        if m.filterLabel <> invalid then m.filterLabel.color = "0xFFFFFF"
        if m.searchLabel <> invalid then m.searchLabel.color = "0x111118"
    else
        m.filterBg.color = "0x2A2A32"
        m.searchBg.color = "0x2A2A32"
        if m.filterLabel <> invalid then m.filterLabel.color = "0xFFFFFF"
        if m.searchLabel <> invalid then m.searchLabel.color = "0xFFFFFF"
    end if
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.focusZone = "filter" then
        if key = "back" then
            if m.filterMode <> "root" then
                m.filterMode = "root"
                buildFilterRoot()
            else
                closeFilterPanel()
            end if
            return true
        end if
        return false
    end if

    if key = "back" then
        m.top.closed = true
        return true
    else if key = "left" and m.focusZone = "grid" then
        m.top.openMenu = true
        return true
    else if key = "up" and m.focusZone = "grid" then
        m.focusZone = "toolbar"
        paintToolbar("filter")
        m.top.setFocus(true)
        return true
    else if key = "down" and m.focusZone = "toolbar" then
        m.focusZone = "grid"
        paintToolbar("")
        m.grid.setFocus(true)
        return true
    else if m.focusZone = "toolbar" then
        if key = "left" or key = "right" then
            if m.toolbarBtn = "filter" then
                paintToolbar("search")
            else
                paintToolbar("filter")
            end if
            return true
        else if key = "OK" then
            if m.toolbarBtn = "search" then
                runSearch()
            else
                openFilterPanel()
            end if
            return true
        end if
    end if
    return false
end function

function joinBits(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
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
    return ""
end function
