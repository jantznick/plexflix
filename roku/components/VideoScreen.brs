sub init()
    m.video = m.top.findNode("video")
    m.statusLabel = m.top.findNode("statusLabel")
    m.video.observeField("state", "onVideoState")
end sub

sub onContentSet()
    item = m.top.content
    cfg = m.top.config
    if item = invalid or cfg = invalid then return

    m.statusLabel.text = "Preparing " + valueOrEmpty(item.title) + "..."
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = cfg
    m.task.action = "streamUrl"
    m.task.item = item
    m.task.observeField("response", "onStreamReady")
    m.task.control = "RUN"
end sub

sub onStreamReady()
    response = m.task.response
    if response = invalid or response.ok <> true or response.url = invalid or response.url = "" then
        err = "Playback failed"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    item = m.top.content
    contentNode = createObject("roSGNode", "ContentNode")
    contentNode.url = response.url
    contentNode.title = valueOrEmpty(item.title)
    contentNode.streamFormat = "hls"
    if item.duration <> invalid then contentNode.length = Int(item.duration / 1000)
    if item.viewOffset <> invalid and item.viewOffset > 0 then
        contentNode.playStart = Int(item.viewOffset / 1000)
    end if

    m.video.content = contentNode
    m.video.control = "play"
    m.statusLabel.visible = false
    m.video.setFocus(true)
end sub

sub onVideoState()
    state = m.video.state
    if state = "error"
        m.statusLabel.visible = true
        m.statusLabel.text = "Video error — try another title or check Plex transcoder"
    else if state = "finished"
        m.top.closed = true
    end if
end sub

sub onCloseRequested()
    if m.top.close = true then
        stopAndClose()
    end if
end sub

sub stopAndClose()
    if m.video <> invalid then m.video.control = "stop"
    m.top.closed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back"
        stopAndClose()
        return true
    end if
    return false
end function

function valueOrEmpty(value as Dynamic) as String
    if value = invalid then return ""
    return value.toStr()
end function