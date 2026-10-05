sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.playBg = m.top.findNode("playBg")
    m.backBg = m.top.findNode("backBg")
    m.playLabel = m.top.findNode("playLabel")
    m.focusIndex = 0
    m.resolvedItem = invalid
    updateButtonFocus()
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return

    m.titleLabel.text = asString(item.title)
    m.summaryLabel.text = asString(item.description)

    metaBits = []
    year = asString(item.year)
    if year <> "" then metaBits.push(year)
    contentRating = asString(item.contentRating)
    if contentRating <> "" then metaBits.push(contentRating)
    rating = asString(item.rating)
    if rating <> "" then metaBits.push(rating + " *")
    mediaType = asString(item.mediaType)
    if mediaType <> "" then metaBits.push(UCase(mediaType))
    m.metaLabel.text = joinStrings(metaBits, "  •  ")

    if item.hdBackdropUrl <> invalid and item.hdBackdropUrl <> "" then
        m.backdrop.uri = item.hdBackdropUrl
    end if
    if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
        m.poster.uri = item.hdPosterUrl
    end if

    if mediaType = "show" or mediaType = "season" then
        m.playLabel.text = "Play"
        resolvePlayable()
    end if
end sub

sub resolvePlayable()
    if m.top.config = invalid or m.top.content = invalid then return
    m.playLabel.text = "Loading..."
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "resolvePlayable"
    m.task.item = m.top.content
    m.task.observeField("response", "onResolved")
    m.task.control = "RUN"
end sub

sub onResolved()
    response = m.task.response
    if response = invalid or response.ok <> true or response.item = invalid then
        m.playLabel.text = "Unavailable"
        return
    end if
    m.resolvedItem = response.item
    m.playLabel.text = "Play"
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

sub updateButtonFocus()
    if m.focusIndex = 0 then
        m.playBg.color = "0xE50914"
        m.backBg.color = "0x2A2A2A"
    else
        m.playBg.color = "0x2A2A2A"
        m.backBg.color = "0xE50914"
    end if
end sub

sub requestPlay()
    item = m.top.content
    mediaType = asString(item.mediaType)

    if mediaType = "show" or mediaType = "season" then
        if m.resolvedItem = invalid then
            resolvePlayable()
            return
        end if
        item = m.resolvedItem
    end if

    if item = invalid then return
    m.top.playRequested = item
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" or key = "right"
        if m.focusIndex = 0 then
            m.focusIndex = 1
        else
            m.focusIndex = 0
        end if
        updateButtonFocus()
        return true
    else if key = "OK"
        if m.focusIndex = 0 then
            requestPlay()
        else
            m.top.closed = true
        end if
        return true
    else if key = "play"
        requestPlay()
        return true
    else if key = "back"
        m.top.closed = true
        return true
    end if

    return false
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