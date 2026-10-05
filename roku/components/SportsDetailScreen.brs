sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.thumb = m.top.findNode("thumb")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.streamList = m.top.findNode("streamList")
    m.streamCountLabel = m.top.findNode("streamCountLabel")
    m.backBg = m.top.findNode("backBg")
    m.backLabel = m.top.findNode("backLabel")
    m.playBg = m.top.findNode("playBg")
    m.playLabel = m.top.findNode("playLabel")
    m.streamList.observeField("itemSelected", "onStreamSelected")
    m.streams = []
    m.eventItem = invalid
    m.focusZone = "play" ' back | play | list
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return
    m.eventItem = item

    m.titleLabel.text = asString(item.title)
    league = asString(item.description)
    if league = "" and item.DoesExist("league") then league = asString(item.league)
    m.metaLabel.text = league
    m.summaryLabel.text = "Choose a feed below. Backup sources appear when the event lists multiple streams."

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

    m.focusZone = "play"
    paintChrome()
    m.top.setFocus(true)
    if m.streamList <> invalid then m.streamList.focusable = false
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

sub paintChrome()
    ' Default chrome
    m.backBg.color = "0x2A2A32"
    if m.backLabel <> invalid then m.backLabel.color = "0xFFFFFF"
    m.playBg.color = "0xE50914"
    if m.playLabel <> invalid then m.playLabel.color = "0xFFFFFF"

    if m.focusZone = "back" then
        m.backBg.color = "0xFFFFFF"
        if m.backLabel <> invalid then m.backLabel.color = "0x111118"
    else if m.focusZone = "play" then
        m.playBg.color = "0xFFFFFF"
        if m.playLabel <> invalid then m.playLabel.color = "0x111118"
    end if
end sub

sub playStreamAt(idx as Integer)
    if idx < 0 or idx >= m.streams.count() then return
    stream = m.streams[idx]
    if stream = invalid then return
    url = asString(stream.streamUrl)
    if url = "" then return

    m.top.playRequested = {
        title: m.titleLabel.text,
        description: m.metaLabel.text,
        mediaType: "sport",
        key: url,
        streamUrl: url,
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

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" then
        m.top.closed = true
        return true
    end if

    if m.focusZone = "back" then
        if key = "OK" then
            m.top.closed = true
            return true
        else if key = "right" then
            m.focusZone = "play"
            paintChrome()
            return true
        else if key = "down" then
            focusStreamList()
            return true
        end if
        return true
    else if m.focusZone = "play" then
        if key = "OK" or key = "play" then
            playStreamAt(0)
            return true
        else if key = "left" then
            m.focusZone = "back"
            paintChrome()
            return true
        else if key = "down" then
            focusStreamList()
            return true
        end if
        return true
    else if m.focusZone = "list" then
        if key = "up" then
            ' Escape handled if at top — also allow explicit up to chrome
            idx = m.streamList.itemFocused
            if idx = invalid or idx = 0 then
                m.focusZone = "play"
                if m.streamList <> invalid then m.streamList.focusable = false
                paintChrome()
                m.top.setFocus(true)
                return true
            end if
        else if key = "back" then
            m.top.closed = true
            return true
        end if
    end if
    return false
end function

sub focusStreamList()
    if m.streams.count() = 0 then return
    m.focusZone = "list"
    paintChrome()
    m.streamList.focusable = true
    m.streamList.setFocus(true)
end sub

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return ""
end function
