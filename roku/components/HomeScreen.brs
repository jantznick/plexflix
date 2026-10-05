sub init()
    m.heroArt = m.top.findNode("heroArt")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroMeta = m.top.findNode("heroMeta")
    m.heroSummary = m.top.findNode("heroSummary")
    m.rowList = m.top.findNode("rowList")

    m.rowList.observeField("rowItemSelected", "onRowItemSelected")
    m.rowList.observeField("rowItemFocused", "onRowItemFocused")

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

    m.rowList.content = content
    m.rowList.setFocus(true)

    ' Seed hero from first playable item
    firstRow = content.getChild(0)
    if firstRow <> invalid and firstRow.getChildCount() > 0 then
        updateHero(firstRow.getChild(0))
    end if
end sub

sub onRowItemFocused()
    info = m.rowList.rowItemFocused
    if info = invalid or info.count() < 2 then return
    row = m.rowList.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return
    updateHero(item)
end sub

sub updateHero(item as Object)
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
    if rating <> "" then metaBits.push(rating + " *")
    mediaType = asString(item.mediaType)
    if mediaType <> "" then metaBits.push(UCase(mediaType))
    m.heroMeta.text = joinStrings(metaBits, "  •  ")
    m.heroSummary.text = asString(item.description)
end sub

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
    if press and key = "OK" and not m.rowList.hasFocus() then
        m.rowList.setFocus(true)
        return true
    end if
    return false
end function