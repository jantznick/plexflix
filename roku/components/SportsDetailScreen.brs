sub init()
    m.thumb = m.top.findNode("thumb")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.streamList = m.top.findNode("streamList")
    m.streamList.observeField("itemSelected", "onStreamSelected")
    m.streams = []
    m.eventItem = invalid
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return
    m.eventItem = item

    m.titleLabel.text = asString(item.title)
    m.metaLabel.text = asString(item.description)
    m.summaryLabel.text = "Pick a stream below. Multiple feeds may be listed when the event has backup sources."

    if asString(item.hdPosterUrl) <> "" then m.thumb.uri = item.hdPosterUrl

    m.streams = item.streams
    if m.streams = invalid then m.streams = []
    if m.streams.count() = 0 and asString(item.streamUrl) <> "" then
        m.streams = [{ title: "Primary stream", streamUrl: asString(item.streamUrl) }]
    end if

    root = createObject("roSGNode", "ContentNode")
    for each stream in m.streams
        child = root.createChild("ContentNode")
        child.title = asString(stream.title)
        if child.title = "" then child.title = "Stream"
    end for
    m.streamList.content = root
    if m.streams.count() > 0 then
        m.streamList.jumpToItem = 0
        m.streamList.setFocus(true)
    end if
end sub

sub onStreamSelected()
    idx = m.streamList.itemSelected
    if idx = invalid or idx < 0 or idx >= m.streams.count() then return
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

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
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
