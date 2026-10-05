sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.genreList = m.top.findNode("genreList")
    m.grid = m.top.findNode("grid")
    m.spinner = m.top.findNode("spinner")
    m.searchBg = m.top.findNode("searchBg")
    m.clearBg = m.top.findNode("clearBg")

    m.sectionId = ""
    m.activeGenre = "All"
    m.activeSearch = ""
    m.focusZone = "grid" ' grid | filter | toolbar

    m.genreList.observeField("itemFocused", "onGenreFocused")
    m.genreList.observeField("itemSelected", "onGenreSelected")
    m.grid.observeField("itemSelected", "onGridSelected")
end sub

sub onSourceSet()
    source = m.top.source
    if source = invalid then return
    title = asString(source.title)
    if title <> "" then m.titleLabel.text = title + " · All"
    m.sectionId = asString(source.sectionId)
    m.activeSearch = asString(source.search)
    buildGenreList(source.genres)
    loadAll()
end sub

sub buildGenreList(genres as Object)
    root = createObject("roSGNode", "ContentNode")
    if genres = invalid or genres.count() = 0 then
        child = root.createChild("ContentNode")
        child.title = "All"
        child.addFields({ tag: "" })
    else
        for each g in genres
            child = root.createChild("ContentNode")
            child.title = asString(g.title)
            child.addFields({ tag: asString(g.tag) })
        end for
    end if
    m.genreList.content = root
end sub

sub loadAll()
    m.metaLabel.text = buildMetaLine()
    if m.spinner <> invalid then
        m.spinner.visible = true
        m.spinner.control = "start"
    end if
    m.top.loadingMessage = "Loading titles..."
    m.grid.visible = false

    req = m.top.source
    if req = invalid then req = {}
    payload = {
        title: asString(req.title),
        sectionId: m.sectionId,
        genre: m.activeGenre,
        search: m.activeSearch
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
    if m.activeSearch <> "" then bits.push("Search: " + m.activeSearch)
    if bits.count() = 0 then return "All titles · A–Z"
    return joinBits(bits, "  ·  ")
end function

sub onLoaded()
    if m.spinner <> invalid then
        m.spinner.control = "stop"
        m.spinner.visible = false
    end if
    m.top.loadingMessage = ""

    response = m.task.response
    if response = invalid or response.ok <> true then
        err = "Could not load titles"
        if response <> invalid and response.error <> invalid then err = response.error
        m.metaLabel.text = err
        return
    end if

    count = 0
    if response.count <> invalid then count = response.count
    m.metaLabel.text = buildMetaLine() + "  ·  " + StrI(count).Trim() + " titles"

    content = response.content
    if content = invalid or content.getChildCount() = 0 then
        m.metaLabel.text = "No titles match this filter"
        return
    end if

    m.grid.content = content
    m.grid.visible = true
    m.grid.setFocus(true)
    m.focusZone = "grid"
end sub

sub onGenreFocused()
    idx = m.genreList.itemFocused
    if idx = invalid or idx < 0 then return
    row = m.genreList.content.getChild(idx)
    if row = invalid then return
    tag = asString(row.tag)
    if tag = "" then
        m.activeGenre = "All"
    else
        m.activeGenre = asString(row.title)
    end if
end sub

sub onGenreSelected()
    loadAll()
    m.grid.setFocus(true)
    m.focusZone = "grid"
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

sub runSearch()
    m.searchTask = createObject("roSGNode", "SearchKeyboardTask")
    m.searchTask.prompt = "Search " + m.titleLabel.text
    m.searchTask.initialText = m.activeSearch
    m.searchTask.observeField("result", "onSearchDone")
    m.searchTask.control = "RUN"
end sub

sub onSearchDone()
    if m.searchTask.cancelled = true then return
    m.activeSearch = asString(m.searchTask.result)
    loadAll()
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" then
        m.top.closed = true
        return true
    else if key = "left" then
        if m.focusZone = "grid" then
            m.genreList.setFocus(true)
            m.focusZone = "filter"
            return true
        else if m.focusZone = "filter" then
            m.top.openMenu = true
            return true
        end if
    else if key = "right" then
        if m.focusZone = "filter" then
            m.grid.setFocus(true)
            m.focusZone = "grid"
            return true
        end if
    else if key = "up" and m.focusZone = "grid" then
        m.focusZone = "toolbar"
        paintToolbarFocus("search")
        m.top.setFocus(true)
        return true
    else if key = "down" and m.focusZone = "toolbar" then
        m.grid.setFocus(true)
        m.focusZone = "grid"
        paintToolbarFocus("")
        return true
    else if key = "OK" and m.focusZone = "toolbar" then
        if m.toolbarBtn = "clear" then
            m.activeSearch = ""
            m.activeGenre = "All"
            m.genreList.jumpToItem = 0
            loadAll()
        else
            runSearch()
        end if
        return true
    end if
    return false
end function

sub paintToolbarFocus(which as String)
    m.toolbarBtn = which
    if m.searchBg = invalid then return
    if which = "search" then
        m.searchBg.color = "0xFFFFFF"
        m.clearBg.color = "0x2A2A32"
    else if which = "clear" then
        m.searchBg.color = "0x2A2A32"
        m.clearBg.color = "0xFFFFFF"
    else
        m.searchBg.color = "0x2A2A32"
        m.clearBg.color = "0x2A2A32"
    end if
end sub

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
