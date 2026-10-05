sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.rowList = m.top.findNode("rowList")
    m.shimmer = m.top.findNode("shimmer")
    m.viewAllBg = m.top.findNode("viewAllBg")
    m.heroTiles = []
    for i = 0 to 7
        tile = m.top.findNode("tile" + StrI(i).Trim())
        if tile <> invalid then m.heroTiles.push(tile)
    end for

    m.sectionId = ""
    m.genres = []
    m.focusZone = "hero"

    m.rowList.observeField("rowItemSelected", "onRowItemSelected")
    m.rowList.observeField("escapeLeft", "onEscapeLeft")
    m.rowList.observeField("escapeUp", "onEscapeUp")
end sub

sub onEscapeLeft()
    m.top.openMenu = true
end sub

sub onEscapeUp()
    m.focusZone = "hero"
    paintHeroFocus()
    m.top.setFocus(true)
end sub

sub onRefocus()
    if m.top.refocus = true then
        m.focusZone = "hero"
        paintHeroFocus()
        m.top.setFocus(true)
    end if
end sub

sub onSourceSet()
    source = m.top.source
    if source = invalid then return
    title = asString(source.title)
    if title <> "" then m.titleLabel.text = title
    loadBrowse()
end sub

sub loadBrowse()
    m.statusLabel.text = "Loading…"
    m.top.loadingMessage = "Loading " + m.titleLabel.text + "..."
    if m.shimmer <> invalid then m.shimmer.active = true
    m.rowList.visible = false
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "sectionBrowse"
    m.task.item = m.top.source
    m.task.observeField("response", "onBrowseLoaded")
    m.task.control = "RUN"
end sub

sub onBrowseLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if m.shimmer <> invalid then m.shimmer.active = false

    if response = invalid or response.ok <> true then
        err = "Could not load library"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    m.sectionId = asString(response.sectionId)
    if m.sectionId = "" then m.sectionId = asString(m.top.source.sectionId)
    m.genres = response.genres
    if m.genres = invalid then m.genres = []

    applyHeroTiles(response.heroPosters)

    content = response.content
    if content <> invalid and content.getChildCount() > 0 then
        m.statusLabel.text = ""
        m.rowList.content = content
        m.rowList.visible = true
    else
        m.statusLabel.text = "Use View all to browse this library"
    end if

    m.focusZone = "hero"
    paintHeroFocus()
    m.top.setFocus(true)
end sub

sub applyHeroTiles(urls as Object)
    if urls = invalid then urls = []
    for i = 0 to m.heroTiles.count() - 1
        tile = m.heroTiles[i]
        if i < urls.count() and asString(urls[i]) <> "" then
            tile.uri = urls[i]
            tile.opacity = 0.88
        else
            tile.uri = "pkg:/images/poster_placeholder.png"
            tile.opacity = 0.35
        end if
    end for
end sub

sub paintHeroFocus()
    if m.viewAllBg = invalid then return
    if m.focusZone = "hero" then
        m.viewAllBg.color = "0xFFFFFF"
    else
        m.viewAllBg.color = "0xE50914"
    end if
end sub

sub requestViewAll()
    src = m.top.source
    if src = invalid then src = {}
    m.top.viewAllRequested = {
        title: m.titleLabel.text,
        sectionId: m.sectionId,
        key: asString(src.key),
        genres: m.genres
    }
end sub

sub onRowItemSelected()
    info = m.rowList.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.rowList.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return
    m.top.selectedItem = nodeToItem(item)
end sub

function nodeToItem(item as Object) as Object
    return {
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
        grandparentRatingKey: item.grandparentRatingKey,
        parentRatingKey: item.parentRatingKey,
        grandparentTitle: item.grandparentTitle,
        index: item.index,
        shortTitle: item.shortTitle
    }
end function

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.focusZone = "hero" then
        if key = "left" then
            m.top.openMenu = true
            return true
        else if key = "down" then
            if m.rowList.visible = true and m.rowList.content <> invalid and m.rowList.content.getChildCount() > 0 then
                m.focusZone = "rows"
                paintHeroFocus()
                m.rowList.setFocus(true)
                return true
            end if
        else if key = "OK" then
            requestViewAll()
            return true
        end if
    else if key = "back" then
        m.top.closed = true
        return true
    end if
    return false
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return ""
end function
