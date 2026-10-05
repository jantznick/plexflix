sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.heroHint = m.top.findNode("heroHint")
    m.statusLabel = m.top.findNode("statusLabel")
    m.rowList = m.top.findNode("rowList")
    m.shimmer = m.top.findNode("shimmer")
    m.viewAllBg = m.top.findNode("viewAllBg")
    m.viewAllLabel = m.top.findNode("viewAllLabel")
    m.searchBg = m.top.findNode("searchBg")
    m.searchLabel = m.top.findNode("searchLabel")
    m.mosaic = m.top.findNode("mosaic")
    m.heroTiles = []

    m.sectionId = ""
    m.sectionType = ""
    m.genres = []
    m.focusZone = "hero"
    m.heroBtn = "viewall"
    m.loaded = false

    ' Prevent shelves from stealing focus until the user presses Down
    if m.rowList <> invalid then m.rowList.focusable = false

    m.rowList.observeField("rowItemSelected", "onRowItemSelected")
    m.rowList.observeField("escapeLeft", "onEscapeLeft")
    m.rowList.observeField("escapeUp", "onEscapeUp")

    ' Re-assert View all focus after async loads (RowList loves to steal it)
    m.focusGuard = createObject("roSGNode", "Timer")
    m.focusGuard.repeat = false
    m.focusGuard.duration = 0.05
    m.focusGuard.observeField("fire", "onFocusGuard")

    paintHeroFocus()
end sub

sub onEscapeLeft()
    m.top.openMenu = true
end sub

sub onEscapeUp()
    focusHero()
end sub

sub onRefocus()
    if m.top.refocus = true then focusHero()
end sub

sub onSuspendedChange()
    if m.top.suspended = true then
        ' Another screen owns the remote; make sure no timer yanks focus back
        m.focusGuard.control = "stop"
    end if
end sub

function isSuspended() as Boolean
    return m.top.suspended = true
end function

sub focusHero()
    if isSuspended() then return
    m.focusZone = "hero"
    if m.rowList <> invalid then m.rowList.focusable = false
    paintHeroFocus()
    m.top.setFocus(true)
    m.focusGuard.control = "start"
end sub

sub onFocusGuard()
    if isSuspended() then return
    if m.focusZone = "hero" then
        if m.rowList <> invalid then m.rowList.focusable = false
        m.top.setFocus(true)
        paintHeroFocus()
    end if
end sub

sub onSourceSet()
    source = m.top.source
    if source = invalid then return
    title = asString(source.title)
    if title <> "" then m.titleLabel.text = title
    m.sectionType = asString(source.sectionType)
    m.sectionId = asString(source.sectionId)
    if m.heroHint <> invalid then
        if m.sectionType = "show" then
            m.heroHint.text = "Every series in this library — filter, search or sort it however you like."
        else
            m.heroHint.text = "Everything in this library — filter, search or sort it however you like."
        end if
    end if
    loadBrowse()
end sub

sub loadBrowse()
    m.loaded = false
    m.statusLabel.text = "Loading…"
    m.top.loadingMessage = "Loading " + m.titleLabel.text + "..."
    if m.shimmer <> invalid then m.shimmer.active = true
    m.rowList.visible = false
    if m.rowList <> invalid then m.rowList.focusable = false
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
        focusHero()
        return
    end if

    m.loaded = true
    m.sectionId = asString(response.sectionId)
    if m.sectionId = "" then m.sectionId = asString(m.top.source.sectionId)
    if asString(response.sectionType) <> "" then m.sectionType = asString(response.sectionType)
    m.genres = response.genres
    if m.genres = invalid then m.genres = []

    buildMosaic(response.heroPosters)

    content = response.content
    if content <> invalid and content.getChildCount() > 0 then
        m.statusLabel.text = "Down for shelves · OK for the full grid"
        m.rowList.content = content
        m.rowList.visible = true
        m.rowList.focusable = false
    else
        m.statusLabel.text = "Use View all to browse this library"
    end if

    focusHero()
end sub

sub buildMosaic(urls as Object)
    if m.mosaic = invalid then return
    ' Clear previous tiles
    while m.mosaic.getChildCount() > 0
        m.mosaic.removeChildIndex(0)
    end while
    m.heroTiles = []

    if urls = invalid then urls = []
    pool = []
    for each u in urls
        if asString(u) <> "" then pool.push(u)
    end for
    if pool.count() = 0 then pool.push("pkg:/images/poster_placeholder.png")

    ' Dense 2-row mosaic across the hero band — clipped by mosaicClip
    cols = 12
    rows = 2
    tileW = 168
    tileH = 252
    gapX = 10
    gapY = 10
    startX = -40
    startY = -30
    idx = 0
    for r = 0 to rows - 1
        rowOffset = 0
        if r = 1 then rowOffset = 40
        for c = 0 to cols - 1
            xJitter = (c mod 3) * 6
            yJitter = ((c + r) mod 4) * 8
            ' Slight size variation for mosaic feel
            tw = tileW
            th = tileH
            if (c + r) mod 5 = 0 then
                tw = 150
                th = 225
            else if (c + r) mod 7 = 0 then
                tw = 180
                th = 270
            end if
            tile = createObject("roSGNode", "Poster")
            tile.width = tw
            tile.height = th
            tile.loadDisplayMode = "scaleToZoom"
            tile.uri = pool[idx mod pool.count()]
            tile.opacity = 0.55 + ((c + r) mod 4) * 0.1
            tile.translation = [startX + c * (tileW + gapX) + rowOffset + xJitter, startY + r * (tileH + gapY) + yJitter]
            m.mosaic.appendChild(tile)
            m.heroTiles.push(tile)
            idx = idx + 1
        end for
    end for
end sub

sub paintHeroFocus()
    if m.viewAllBg = invalid then return
    heroFocused = (m.focusZone = "hero")

    if heroFocused and m.heroBtn = "viewall" then
        m.viewAllBg.color = "0xFFFFFF"
        if m.viewAllLabel <> invalid then m.viewAllLabel.color = "0x111118"
    else if heroFocused then
        m.viewAllBg.color = "0x2A2A32"
        if m.viewAllLabel <> invalid then m.viewAllLabel.color = "0xFFFFFF"
    else
        m.viewAllBg.color = "0xE50914"
        if m.viewAllLabel <> invalid then m.viewAllLabel.color = "0xFFFFFF"
    end if

    if m.searchBg <> invalid then
        if heroFocused and m.heroBtn = "search" then
            m.searchBg.color = "0xFFFFFF"
            if m.searchLabel <> invalid then m.searchLabel.color = "0x111118"
        else
            m.searchBg.color = "0x2A2A32"
            if m.searchLabel <> invalid then m.searchLabel.color = "0xFFFFFF"
        end if
    end if
end sub

sub requestViewAll(openSearch as Boolean)
    src = m.top.source
    if src = invalid then src = {}
    sectionId = m.sectionId
    if sectionId = "" then sectionId = asString(src.sectionId)
    sectionType = m.sectionType
    if sectionType = "" then sectionType = asString(src.sectionType)
    genres = m.genres
    if genres = invalid then genres = []
    m.top.viewAllRequested = {
        title: m.titleLabel.text,
        sectionId: sectionId,
        sectionType: sectionType,
        key: asString(src.key),
        genres: genres,
        openSearch: openSearch
    }
end sub

sub onRowItemSelected()
    if m.focusZone <> "rows" then return
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

function hasShelves() as Boolean
    if m.rowList = invalid then return false
    if m.rowList.visible <> true then return false
    if m.rowList.content = invalid then return false
    return m.rowList.content.getChildCount() > 0
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.focusZone = "hero" then
        if key = "left" then
            if m.heroBtn = "search" then
                m.heroBtn = "viewall"
                paintHeroFocus()
            else
                m.top.openMenu = true
            end if
            return true
        else if key = "right" then
            if m.heroBtn = "viewall" then
                m.heroBtn = "search"
                paintHeroFocus()
            end if
            return true
        else if key = "down" then
            if hasShelves() then
                m.focusZone = "rows"
                paintHeroFocus()
                m.rowList.focusable = true
                m.rowList.setFocus(true)
            end if
            return true
        else if key = "OK" or key = "play" then
            if m.loaded then requestViewAll(m.heroBtn = "search")
            return true
        else if key = "back" then
            m.top.closed = true
            return true
        end if
        ' Swallow the rest so shelves can't activate while the hero owns focus
        return true
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
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    return ""
end function
