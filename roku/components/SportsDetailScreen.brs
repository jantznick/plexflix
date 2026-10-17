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
    m.lastPlayAt = 0

    m.streamList.observeField("itemSelected", "onStreamSelected")
    m.streamList.observeField("escapeBack", "onListEscapeBack")
    m.streamList.observeField("escapeOptions", "onListEscapeOptions")
    ' If anything clears list focus while this page is active, pin it back.
    m.top.observeField("focusedChild", "onDetailFocusedChild")
    m.focusTimer = m.top.findNode("focusTimer")
    m.focusTimer.observeField("fire", "onFocusTick")
    m.focusTimer.control = "start"
end sub

sub onDetailFocusedChild()
    if not m.top.isInFocusChain() then return
    if m.streams.count() = 0 then return
    if m.streamList <> invalid and m.streamList.isInFocusChain() then return
    focusStreamList()
end sub

sub onFocusTick()
    if not m.top.isInFocusChain() then return
    if m.streams.count() = 0 then return
    if m.streamList <> invalid and m.streamList.isInFocusChain() then return
    focusStreamList()
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return
    m.eventItem = item

    m.titleLabel.text = asString(item.title)
    league = asString(item.description)
    if league = "" and item.DoesExist("league") then league = asString(item.league)
    meta = league
    if item.DoesExist("scoreMatched") and item.scoreMatched = true then
        scoreLine = asString(item.scoreLine)
        scoreStatus = asString(item.scoreStatus)
        bits = scoreLine
        if scoreStatus <> "" and scoreStatus <> scoreLine then
            if bits <> "" then bits = bits + "  ·  "
            bits = bits + scoreStatus
        end if
        if bits <> "" then
            if meta <> "" then meta = meta + "  ·  "
            meta = meta + bits
        end if
    end if
    m.metaLabel.text = meta
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
        setStreamCols(child, StrI(i + 1).Trim(), label, quality, "")
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
    ' itemSelected and parent OK can both fire for one press — only play once
    now = CreateObject("roDateTime").AsSeconds()
    if m.lastPlayAt <> 0 and now - m.lastPlayAt < 1 then return
    if idx < 0 or idx >= m.streams.count() then return
    stream = m.streams[idx]
    if stream = invalid then return
    url = asString(stream.streamUrl)
    if url = "" then return
    format = asString(stream.streamFormat)
    if format = "" and idx = 0 then format = asString(m.eventItem.streamFormat)

    m.lastPlayAt = now
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

sub onListEscapeOptions()
    if m.top.multiviewEnabled = true then toggleFocusedStream()
end sub

sub onCloseRequested()
    if m.top.close <> true then return
    if m.focusTimer <> invalid then m.focusTimer.control = "stop"
    m.top.closed = true
end sub

sub onRefocus()
    if m.top.refocus <> true then return
    if m.streams.count() = 0 then
        m.top.setFocus(true)
        return
    end if
    focusStreamList()
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
        m.summaryLabel.text = "* adds to multiview · OK plays this stream · Play starts multiview"
    else
        m.summaryLabel.text = ""
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
    focusStreamList()
end sub

' This page always keeps a stream row focused while it is on screen.
sub focusStreamList()
    if m.streams.count() = 0 then return
    if m.streamList = invalid then return
    m.streamList.focusable = true
    m.streamList.setFocus(true)
end sub

sub toggleFocusedStream()
    if m.streamList = invalid or not m.streamList.isInFocusChain() then
        focusStreamList()
        return
    end if
    idx = m.streamList.itemFocused
    if idx = invalid or idx < 0 or idx >= m.streams.count() then
        focusStreamList()
        return
    end if
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
    ' Keep the lit row here — the guide underneath must not take focus.
    focusStreamList()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" or key = "left" then
        m.top.closed = true
        return true
    end if
    if key = "OK" then
        if m.streamList = invalid or not m.streamList.isInFocusChain() then
            focusStreamList()
            return true
        end if
        idx = 0
        if m.streamList.itemFocused <> invalid then idx = m.streamList.itemFocused
        playStreamAt(idx)
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
    if m.streamList <> invalid and not m.streamList.isInFocusChain() then
        if key = "up" or key = "down" or key = "rewind" or key = "fastforward" then
            focusStreamList()
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
