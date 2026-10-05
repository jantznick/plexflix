sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.rowList = m.top.findNode("rowList")
    m.shimmer = m.top.findNode("shimmer")
    m.viewAllBg = m.top.findNode("viewAllBg")
    m.viewAllLabel = m.top.findNode("viewAllLabel")
    m.mosaic = m.top.findNode("mosaic")
    m.heroTiles = []

    m.sectionId = ""
    m.genres = []
    m.focusZone = "hero"

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

sub focusHero()
    m.focusZone = "hero"
    if m.rowList <> invalid then m.rowList.focusable = false
    paintHeroFocus()
    m.top.setFocus(true)
    m.focusGuard.control = "start"
end sub

sub onFocusGuard()
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
    loadBrowse()
end sub

sub loadBrowse()
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

    m.sectionId = asString(response.sectionId)
    if m.sectionId = "" then m.sectionId = asString(m.top.source.sectionId)
    m.genres = response.genres
    if m.genres = invalid then m.genres = []

    buildMosaic(response.heroPosters)

    content = response.content
    if content <> invalid and content.getChildCount() > 0 then
        m.statusLabel.text = ""
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

    ' Dense 3-row mosaic covering the full hero width — no dead space
    cols = 12
    rows = 3
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
        if r = 2 then rowOffset = -20
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
    if m.focusZone = "hero" then
        ' Focused: white plate + dark label (never white-on-white)
        m.viewAllBg.color = "0xFFFFFF"
        if m.viewAllLabel <> invalid then m.viewAllLabel.color = "0x111118"
    else
        m.viewAllBg.color = "0xE50914"
        if m.viewAllLabel <> invalid then m.viewAllLabel.color = "0xFFFFFF"
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
                m.rowList.focusable = true
                m.rowList.setFocus(true)
                return true
            end if
            return true
        else if key = "OK" or key = "play" then
            requestViewAll()
            return true
        else if key = "back" then
            m.top.closed = true
            return true
        end if
        ' Swallow other keys so shelves can't activate while View all is focused
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
    return ""
end function
