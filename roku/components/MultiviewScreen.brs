sub init()
    m.video = m.top.findNode("video")
    m.tileLayer = m.top.findNode("tileLayer")
    m.hintBar = m.top.findNode("hintBar")
    m.layoutLabel = m.top.findNode("layoutLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.spinner = m.top.findNode("spinner")
    PinSpinner(m.spinner)

    m.pollTimer = m.top.findNode("pollTimer")
    m.pollTimer.observeField("fire", "onPollTimer")
    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "onHideTimer")
    m.settleTimer = m.top.findNode("settleTimer")
    m.settleTimer.observeField("fire", "onSettled")
    m.retryTimer = m.top.findNode("retryTimer")
    m.retryTimer.observeField("fire", "onRetry")
    m.stallTimer = m.top.findNode("stallTimer")
    m.stallTimer.observeField("fire", "onStall")

    m.streams = []
    m.session = invalid
    m.sessionId = ""
    m.tiles = []
    m.tileNodes = []
    m.focus = 0
    m.playing = false
    m.promoted = false
    m.closing = false
    ' A layout change or reorder is in flight: the video still shows the old
    ' arrangement for a while, so the overlay waits rather than lying about it
    m.switching = false
    m.overlayVisible = false
    m.recreated = false
    m.notice = ""
    m.shownOnce = false
    m.focusAfterSwitch = invalid
    m.switchMessage = ""
    m.requestedLayout = "grid"

    m.video.focusable = false
    m.video.observeField("state", "onVideoState")
    m.video.observeField("availableAudioTracks", "onAudioTracks")
    m.top.observeField("focusedChild", "onFocusedChild")
end sub

'--------------------------------------------------------------------
' Session lifecycle
'--------------------------------------------------------------------

sub onContentSet()
    content = m.top.content
    if content = invalid or content.streams = invalid then return
    m.streams = content.streams
    m.requestedLayout = "grid"
    if content.layout <> invalid and content.layout <> "" then m.requestedLayout = content.layout
    createSession()
end sub

sub createSession()
    m.pollTimer.control = "stop"
    streams = []
    for each stream in m.streams
        streams.push({ url: asString(stream.url), title: asString(stream.title) })
    end for
    setStatus("Starting multiview with " + StrI(streams.count()).Trim() + " games...")

    m.createTask = createObject("roSGNode", "MultiviewTask")
    m.createTask.config = m.top.config
    m.createTask.action = "create"
    m.createTask.item = { streams: streams, layout: m.requestedLayout }
    m.createTask.observeField("response", "onCreated")
    m.createTask.control = "RUN"
end sub

sub onCreated()
    if m.closing then return
    response = m.createTask.response
    if response = invalid or response.ok <> true then
        err = "Couldn't start multiview"
        if response <> invalid and response.error <> invalid then err = response.error
        showError(err)
        return
    end if
    m.focus = 0
    adoptSession(response.session)
    m.pollTimer.duration = 2
    m.pollTimer.control = "start"
end sub

sub onPollTimer()
    if m.closing or m.sessionId = "" then return
    ' One status request at a time; a slow server shouldn't stack them up
    if m.pollTask <> invalid and m.pollTask.state = "run" then return
    m.pollTask = createObject("roSGNode", "MultiviewTask")
    m.pollTask.config = m.top.config
    m.pollTask.action = "status"
    m.pollTask.item = { id: m.sessionId }
    m.pollTask.observeField("response", "onPolled")
    m.pollTask.control = "RUN"
end sub

sub onPolled()
    if m.closing then return
    response = m.pollTask.response
    if response = invalid then return
    if response.ok <> true then
        ' The server restarted or reaped us. Starting over once is worth it;
        ' a second loss in a row is reported instead of looping
        if response.code <> invalid then
            if response.code = 404 and not m.recreated then
                m.recreated = true
                stopVideo()
                m.sessionId = ""
                createSession()
            end if
        end if
        return
    end if
    m.recreated = false
    adoptSession(response.session)
end sub

sub adoptSession(session as Object)
    if session = invalid then return
    m.session = session
    m.sessionId = asString(session.id)
    m.top.sessionId = m.sessionId

    if session.state = "error" and not m.playing then
        showError(asString(session.error))
        return
    end if

    if not m.switching then
        m.tiles = session.tiles
        if m.tiles = invalid then m.tiles = []
        if m.focus >= m.tiles.count() then m.focus = 0
        paintTiles()
    end if

    if session.state = "running" then
        if m.pollTimer.duration <> 5 then
            m.pollTimer.duration = 5
            m.pollTimer.control = "start"
        end if
        if not m.playing and not m.promoted then startPlayback()
    else if not m.playing and not m.promoted then
        setStatus("Starting multiview" + readySuffix())
    end if
end sub

' "· 2 of 3 games ready" while the server is still bringing feeds up
function readySuffix() as String
    if m.tiles.count() = 0 then return "..."
    ready = 0
    for each tile in m.tiles
        if tile.status <> "starting" then ready = ready + 1
    end for
    return "...  " + StrI(ready).Trim() + " of " + StrI(m.tiles.count()).Trim() + " games ready"
end function

'--------------------------------------------------------------------
' Playback
'--------------------------------------------------------------------

sub startPlayback()
    if m.session = invalid then return
    base = ""
    cfg = m.top.config
    if cfg <> invalid and cfg.multiviewUrl <> invalid then base = cfg.multiviewUrl
    while Right(base, 1) = "/"
        base = Left(base, Len(base) - 1)
    end while

    node = createObject("roSGNode", "ContentNode")
    node.url = base + asString(m.session.playlistUrl)
    node.streamFormat = "hls"
    node.title = "Multiview"
    node.live = true
    m.video.content = node
    m.video.control = "play"
    m.playing = true
    if not m.switching then setStatus("Loading games...")
    restartStallTimer()
    ensureFocus()
end sub

sub stopVideo()
    m.stallTimer.control = "stop"
    m.retryTimer.control = "stop"
    m.video.control = "stop"
    m.playing = false
end sub

sub onVideoState()
    state = m.video.state
    print "[plexflix:multiview] state=" + state
    if state = "playing" or state = "paused" or state = "buffering" then ensureFocus()

    if state = "playing" then
        m.stallTimer.control = "stop"
        if not m.switching and m.notice = "" then clearStatus()
        applyAudio()
        if not m.shownOnce then
            m.shownOnce = true
            showOverlay()
        end if
    else if state = "buffering" then
        if not m.switching and m.notice = "" then setStatus("Buffering...")
        restartStallTimer()
    else if state = "error" or state = "finished" then
        ' A live mosaic never legitimately ends, and the server keeps it going
        ' through feed trouble, so a stop here is worth retrying quietly
        if m.promoted or m.closing then return
        print "[plexflix:multiview] " + state + " " + asString(m.video.errorMsg)
        m.playing = false
        m.stallTimer.control = "stop"
        setStatus("Multiview dropped, reconnecting...")
        m.retryTimer.control = "start"
    end if
end sub

sub onRetry()
    if m.promoted or m.closing then return
    if m.session <> invalid and m.session.state = "running" then
        startPlayback()
    end if
    ' Otherwise the next poll starts playback once the server is running again
end sub

sub restartStallTimer()
    m.stallTimer.control = "stop"
    m.stallTimer.control = "start"
end sub

sub onStall()
    if m.video.state = "playing" or m.promoted or m.closing then return
    stopVideo()
    setStatus("Multiview stalled, reconnecting...")
    m.retryTimer.control = "start"
end sub

sub onAudioTracks()
    applyAudio()
end sub

' The server names its audio renditions "Tile 1".."Tile N" by slot. Matched
' by name first, since nothing promises the firmware keeps playlist order
sub applyAudio()
    tracks = m.video.availableAudioTracks
    if tracks = invalid or tracks.count() = 0 or m.tiles.count() = 0 then return

    slot = m.focus
    tile = m.tiles[slot]
    if tile <> invalid and tile.audioTrack <> invalid then slot = tile.audioTrack

    wanted = "Tile " + StrI(slot + 1).Trim()
    chosen = invalid
    for each track in tracks
        if asString(track.Name) = wanted then
            chosen = track
            exit for
        end if
    end for
    if chosen = invalid then
        index = slot
        if index >= tracks.count() then index = tracks.count() - 1
        chosen = tracks[index]
    end if

    id = asString(chosen.Track)
    if id <> "" and asString(m.video.audioTrack) <> id then m.video.audioTrack = id
end sub

'--------------------------------------------------------------------
' Layout changes
'--------------------------------------------------------------------

sub cycleLayout()
    if m.session = invalid or m.session.layouts = invalid then return
    layouts = m.session.layouts
    if layouts.count() = 0 then return
    nextLayout = layouts[0]
    for i = 0 to layouts.count() - 1
        if layouts[i] = m.session.layout then
            nextLayout = layouts[(i + 1) MOD layouts.count()]
            exit for
        end if
    end for
    requestUpdate({ layout: nextLayout }, "Switching to " + layoutName(nextLayout) + "...")
end sub

' Moves the focused game into the first slot: the big tile in Spotlight and
' Picture in picture, top left in Grid
sub makeMain()
    if m.session = invalid or m.session.order = invalid or m.focus = 0 then return
    order = m.session.order
    focused = order[m.focus]
    reordered = [focused]
    for each stream in order
        if stream <> focused then reordered.push(stream)
    end for
    m.focusAfterSwitch = 0
    requestUpdate({ order: reordered }, "Moving " + tileTitle(m.focus) + " to the main spot...")
end sub

sub requestUpdate(payload as Object, message as String)
    if m.switching or m.sessionId = "" then return
    payload.id = m.sessionId
    m.switchMessage = message
    m.updateTask = createObject("roSGNode", "MultiviewTask")
    m.updateTask.config = m.top.config
    m.updateTask.action = "update"
    m.updateTask.item = payload
    m.updateTask.observeField("response", "onUpdated")
    m.updateTask.control = "RUN"
end sub

sub onUpdated()
    if m.closing then return
    response = m.updateTask.response
    if response = invalid or response.ok <> true then
        err = "Couldn't change the layout"
        if response <> invalid and response.error <> invalid then err = response.error
        m.focusAfterSwitch = invalid
        showNotice(err)
        return
    end if

    m.session = response.session
    m.switching = true
    hideOverlay()
    m.tileLayer.visible = false
    setStatus(m.switchMessage)
    ' The server restarts in a few seconds, then the new arrangement still has
    ' to travel through the player's live buffer before it is on screen
    m.settleTimer.control = "stop"
    m.settleTimer.duration = 12
    m.settleTimer.control = "start"
end sub

sub onSettled()
    m.switching = false
    if m.focusAfterSwitch <> invalid then
        m.focus = m.focusAfterSwitch
        m.focusAfterSwitch = invalid
    end if
    if m.session <> invalid then
        m.tiles = m.session.tiles
        if m.tiles = invalid then m.tiles = []
        if m.focus >= m.tiles.count() then m.focus = 0
    end if
    m.tileLayer.visible = true
    paintTiles()
    if m.video.state = "playing" then clearStatus()
    applyAudio()
    showOverlay()
end sub

function layoutName(layout as String) as String
    if layout = "grid" then return "Grid"
    if layout = "spotlight" then return "Spotlight"
    if layout = "pip" then return "Picture in picture"
    return layout
end function

'--------------------------------------------------------------------
' Full screen through the regular player
'--------------------------------------------------------------------

sub promoteFocused()
    if m.focus >= m.tiles.count() then return
    tile = m.tiles[m.focus]
    index = tile.stream
    if index = invalid or index < 0 or index >= m.streams.count() then return
    stream = m.streams[index]

    ' Only one decoder: this has to be stopped before the player starts
    stopVideo()
    m.promoted = true
    hideOverlay()
    clearStatus()
    url = asString(stream.url)
    m.top.playRequested = {
        title: asString(stream.title),
        description: asString(stream.league),
        mediaType: "sport",
        key: url,
        streamUrl: url,
        streamFormat: asString(stream.streamFormat),
        hdPosterUrl: asString(stream.hdPosterUrl),
        ratingKey: "",
        duration: 0,
        viewOffset: 0
    }
end sub

sub onResume()
    if m.top.resume <> true then return
    m.promoted = false
    ensureFocus()
    if m.session <> invalid and m.session.state = "running" then
        startPlayback()
    else
        setStatus("Starting multiview" + readySuffix())
    end if
end sub

sub onNotice()
    if m.top.notice <> "" then showNotice(m.top.notice)
end sub

'--------------------------------------------------------------------
' Overlay
'--------------------------------------------------------------------

sub paintTiles()
    if needsRebuild() then rebuildTiles()
    paintFocus()
end sub

function needsRebuild() as Boolean
    if m.tileNodes.count() <> m.tiles.count() then return true
    for i = 0 to m.tiles.count() - 1
        tile = m.tiles[i]
        rect = m.tileNodes[i].rect
        if rect.x <> tile.x or rect.y <> tile.y or rect.w <> tile.w or rect.h <> tile.h then return true
    end for
    return false
end function

sub rebuildTiles()
    while m.tileLayer.getChildCount() > 0
        m.tileLayer.removeChildIndex(0)
    end while
    m.tileNodes = []

    thickness = 6
    for each tile in m.tiles
        group = m.tileLayer.createChild("Group")
        group.translation = [tile.x, tile.y]

        borders = []
        for each spec in [[0, 0, tile.w, thickness], [0, tile.h - thickness, tile.w, thickness], [0, 0, thickness, tile.h], [tile.w - thickness, 0, thickness, tile.h]]
            edge = group.createChild("Rectangle")
            edge.translation = [spec[0], spec[1]]
            edge.width = spec[2]
            edge.height = spec[3]
            edge.color = "0xFFFFFF"
            edge.visible = false
            borders.push(edge)
        end for

        ' Stays up with the rest of the overlay hidden: the one cue for which
        ' game the sound is coming from
        audioBar = group.createChild("Rectangle")
        audioBar.translation = [0, tile.h - thickness]
        audioBar.width = tile.w
        audioBar.height = thickness
        audioBar.color = "0xE50914"
        audioBar.visible = false

        chip = group.createChild("Group")
        chip.translation = [18, 18]
        chipBg = chip.createChild("Rectangle")
        chipBg.color = "0x000000"
        chipBg.opacity = 0.72
        chipBg.height = 74
        title = chip.createChild("Label")
        title.translation = [16, 8]
        title.height = 32
        title.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 24)
        title.color = "0xFFFFFF"
        status = chip.createChild("Label")
        status.translation = [16, 40]
        status.height = 26
        status.font = MakeFont("pkg:/fonts/Outfit-Medium.ttf", 19)

        m.tileNodes.push({
            rect: { x: tile.x, y: tile.y, w: tile.w, h: tile.h },
            borders: borders,
            audioBar: audioBar,
            chip: chip,
            chipBg: chipBg,
            title: title,
            status: status
        })
    end for
end sub

sub paintFocus()
    for i = 0 to m.tileNodes.count() - 1
        node = m.tileNodes[i]
        tile = m.tiles[i]
        focused = (i = m.focus)

        for each edge in node.borders
            edge.visible = focused and m.overlayVisible
        end for
        node.audioBar.visible = focused and not m.switching

        statusText = ""
        statusColor = "0x9A9AA4"
        if tile.status = "reconnecting" then
            statusText = "Reconnecting..."
            statusColor = "0xFFB020"
        else if tile.status = "starting" then
            statusText = "Starting..."
        else if focused then
            statusText = "Sound on"
            statusColor = "0xFF5A5F"
        end if

        node.title.text = asString(tile.title)
        node.status.text = statusText
        node.status.color = statusColor

        longest = Len(node.title.text)
        if Len(statusText) > longest then longest = Len(statusText)
        width = longest * 13 + 40
        if width > tile.w - 36 then width = tile.w - 36
        node.chipBg.width = width
        node.title.width = width - 32
        node.status.width = width - 32
        node.chip.visible = m.overlayVisible
    end for
end sub

sub showOverlay()
    if m.switching or m.promoted then return
    m.overlayVisible = true
    m.hintBar.visible = true
    if m.session <> invalid then m.layoutLabel.text = "Multiview  ·  " + layoutName(asString(m.session.layout))
    paintFocus()
    m.hideTimer.control = "stop"
    m.hideTimer.control = "start"
end sub

sub hideOverlay()
    m.hideTimer.control = "stop"
    m.overlayVisible = false
    m.hintBar.visible = false
    paintFocus()
end sub

sub onHideTimer()
    hideOverlay()
    if m.notice <> "" then
        m.notice = ""
        if m.video.state = "playing" and not m.switching then clearStatus()
    end if
end sub

sub moveFocus(direction as String)
    target = neighbourOf(m.focus, direction)
    if target >= 0 then
        m.focus = target
        applyAudio()
    end if
    showOverlay()
end sub

' Nearest tile centre in the pressed direction, favouring ones in line with
' the current tile, so Picture in picture and Spotlight navigate naturally
function neighbourOf(index as Integer, direction as String) as Integer
    if index >= m.tiles.count() then return -1
    current = m.tiles[index]
    cx = current.x + current.w / 2
    cy = current.y + current.h / 2

    best = -1
    bestScore = 0
    for i = 0 to m.tiles.count() - 1
        if i <> index then
            tile = m.tiles[i]
            dx = tile.x + tile.w / 2 - cx
            dy = tile.y + tile.h / 2 - cy
            along = 0
            across = 0
            if direction = "right" and dx > 0 then
                along = dx
                across = Abs(dy)
            else if direction = "left" and dx < 0 then
                along = -dx
                across = Abs(dy)
            else if direction = "down" and dy > 0 then
                along = dy
                across = Abs(dx)
            else if direction = "up" and dy < 0 then
                along = -dy
                across = Abs(dx)
            end if
            if along > 0 then
                score = along + across * 2
                if best < 0 or score < bestScore then
                    best = i
                    bestScore = score
                end if
            end if
        end if
    end for
    return best
end function

function tileTitle(index as Integer) as String
    if index < 0 or index >= m.tiles.count() then return "that game"
    title = asString(m.tiles[index].title)
    if title = "" then return "that game"
    return title
end function

'--------------------------------------------------------------------
' Remote
'--------------------------------------------------------------------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" then
        closeScreen()
        return true
    end if

    if m.session = invalid or m.tiles.count() = 0 or m.switching then return true

    if key = "up" or key = "down" or key = "left" or key = "right" then
        moveFocus(key)
    else if key = "OK" then
        promoteFocused()
    else if key = "options" then
        cycleLayout()
    else if key = "fastforward" or key = "rewind" then
        makeMain()
    else
        showOverlay()
    end if
    ' Everything is swallowed: Left in particular must not open the side nav
    return true
end function

sub onFocusedChild()
    child = m.top.focusedChild
    if child <> invalid and child.isSameNode(m.video) then ensureFocus()
end sub

sub ensureFocus()
    m.video.focusable = false
    m.top.setFocus(true)
end sub

'--------------------------------------------------------------------
' Teardown
'--------------------------------------------------------------------

sub onCloseRequested()
    if m.top.close = true then closeScreen()
end sub

sub closeScreen()
    if m.closing then return
    m.closing = true
    m.pollTimer.control = "stop"
    m.hideTimer.control = "stop"
    m.settleTimer.control = "stop"
    stopVideo()
    m.top.closed = true
end sub

'--------------------------------------------------------------------
' Helpers
'--------------------------------------------------------------------

sub setStatus(message as String)
    m.statusLabel.visible = true
    m.statusLabel.text = message
    m.spinner.visible = true
    m.spinner.control = "start"
    CenterSpinner(m.spinner, 960)
end sub

sub clearStatus()
    m.statusLabel.visible = false
    m.spinner.control = "stop"
    m.spinner.visible = false
end sub

sub showError(message as String)
    if message = "" then message = "Multiview failed"
    m.spinner.control = "stop"
    m.spinner.visible = false
    m.statusLabel.visible = true
    m.statusLabel.text = message + Chr(10) + "Press Back to return"
end sub

' Shown until the overlay next hides, without the spinner
sub showNotice(message as String)
    m.notice = message
    m.spinner.control = "stop"
    m.spinner.visible = false
    m.statusLabel.visible = true
    m.statusLabel.text = message
    showOverlay()
    if not m.overlayVisible then
        m.hideTimer.control = "stop"
        m.hideTimer.control = "start"
    end if
end sub

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        return Str(value).Trim()
    end if
    return ""
end function
