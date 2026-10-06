sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.thumb = m.top.findNode("thumb")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.streamList = m.top.findNode("streamList")
    m.streamCountLabel = m.top.findNode("streamCountLabel")

    m.streams = []
    m.eventItem = invalid

    m.streamList.observeField("itemSelected", "onStreamSelected")
    m.streamList.observeField("escapeBack", "onListEscapeBack")
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return
    m.eventItem = item

    m.titleLabel.text = asString(item.title)
    league = asString(item.description)
    if league = "" and item.DoesExist("league") then league = asString(item.league)
    m.metaLabel.text = league
    showHint()

    art = asString(item.hdPosterUrl)
    if art = "" then art = asString(item.hdBackdropUrl)
    if art <> "" then
        m.thumb.uri = art
        if m.backdrop <> invalid then m.backdrop.uri = art
    end if

    m.streams = item.streams
    if m.streams = invalid then m.streams = []
    if m.streams.count() = 0 and asString(item.streamUrl) <> "" then
        m.streams = [{ title: "Primary stream", streamUrl: asString(item.streamUrl) }]
    end if

    n = m.streams.count()
    if n = 1 then
        m.streamCountLabel.text = "1 stream available"
    else
        m.streamCountLabel.text = StrI(n).Trim() + " streams available"
    end if

    root = createObject("roSGNode", "ContentNode")
    for i = 0 to m.streams.count() - 1
        stream = m.streams[i]
        child = root.createChild("ContentNode")
        label = asString(stream.title)
        if label = "" then label = "Stream " + StrI(i + 1).Trim()
        child.title = label
        quality = ""
        if stream.DoesExist("quality") then quality = asString(stream.quality)
        setStreamCols(child, StrI(i + 1).Trim(), label, quality, "Play →")
    end for
    m.streamList.content = root
    if m.streams.count() > 0 then
        m.streamList.jumpToItem = 0
        m.streamList.setFocus(true)
    end if
end sub

sub setStreamCols(node as Object, c0 as String, c1 as String, c2 as String, c3 as String)
    node.title = c1
    if node.DoesExist("col0") then
        node.col0 = c0
        node.col1 = c1
        node.col2 = c2
        node.col3 = c3
    else
        node.addFields({ col0: c0, col1: c1, col2: c2, col3: c3 })
    end if
end sub

sub playStreamAt(idx as Integer)
    if idx < 0 or idx >= m.streams.count() then return
    stream = m.streams[idx]
    if stream = invalid then return
    url = asString(stream.streamUrl)
    if url = "" then return
    format = asString(stream.streamFormat)
    if format = "" and idx = 0 then format = asString(m.eventItem.streamFormat)

    m.top.streamError = ""
    m.top.playRequested = {
        title: m.titleLabel.text,
        description: m.metaLabel.text,
        mediaType: "sport",
        key: url,
        streamUrl: url,
        streamFormat: format,
        hdPosterUrl: m.eventItem.hdPosterUrl,
        ratingKey: "",
        duration: 0,
        viewOffset: 0
    }
end sub

sub onStreamSelected()
    idx = m.streamList.itemSelected
    if idx = invalid then return
    playStreamAt(idx)
end sub

sub onListEscapeBack()
    m.top.closed = true
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

sub onRefocus()
    if m.top.refocus <> true then return
    if m.streams.count() = 0 then
        m.top.setFocus(true)
        return
    end if
    ' The list kept its own place, so the stream just tried stays highlighted
    m.streamList.setFocus(true)
end sub

sub onStreamError()
    reason = m.top.streamError
    if reason = "" then
        showHint()
        return
    end if

    idx = m.streamList.itemFocused
    label = ""
    root = m.streamList.content
    if idx <> invalid and root <> invalid and idx >= 0 and idx < root.getChildCount() then
        label = asString(root.getChild(idx).title)
    end if
    if label = "" then label = "That stream"

    hint = "Try another stream."
    if m.streams.count() < 2 then hint = "Try again in a moment."
    m.summaryLabel.color = "0xFF6B6B"
    m.summaryLabel.text = label + " failed: " + reason + ". " + hint
end sub

sub showHint()
    m.summaryLabel.color = "0xC8C8D0"
    if m.top.multiviewEnabled = true then
        m.summaryLabel.text = "OK a stream to play, * to add it to multiview, Play to watch your multiview. Back returns to the guide."
    else
        m.summaryLabel.text = "OK a stream to play. Remote Back returns to the guide."
    end if
end sub

sub onMultiviewEnabled()
    if m.top.streamError = "" then showHint()
end sub

sub onMultiviewNote()
    note = m.top.multiviewNote
    if note = "" then return
    m.summaryLabel.color = "0xC8C8D0"
    m.summaryLabel.text = note
end sub

sub toggleFocusedStream()
    idx = m.streamList.itemFocused
    if idx = invalid or idx < 0 or idx >= m.streams.count() then return
    stream = m.streams[idx]
    title = m.titleLabel.text
    ' Alternates of one game are told apart by their stream label
    if m.streams.count() > 1 then title = title + " (" + asString(stream.title) + ")"
    format = asString(stream.streamFormat)
    if format = "" and idx = 0 then format = asString(m.eventItem.streamFormat)
    m.top.multiviewToggle = {
        url: asString(stream.streamUrl),
        title: title,
        league: m.metaLabel.text,
        streamFormat: format,
        hdPosterUrl: asString(m.eventItem.hdPosterUrl)
    }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" or key = "left" then
        m.top.closed = true
        return true
    end if
    if m.top.multiviewEnabled = true then
        if key = "options" then
            toggleFocusedStream()
            return true
        else if key = "play" then
            m.top.multiviewLaunch = true
            return true
        end if
    end if
    return false
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return ""
end function
