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
    m.rotateTimer = m.top.findNode("rotateTimer")
    m.rotateTimer.observeField("fire", "onRotateDebounced")

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
    m.pendingOrder = invalid

    m.video.focusable = false
    m.video.enableUI = false
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
                m.session = invalid
                m.sessionId = ""
                m.top.sessionId = ""
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
        ' placeholder tiles are intentionally not decoding
        if tile.status <> "starting" and tile.status <> "reconnecting" then ready = ready + 1
    end for
    return "...  " + StrI(ready).Trim() + " of " + StrI(m.tiles.count()).Trim() + " games ready"
end function

'--------------------------------------------------------------------
' Playback
'--------------------------------------------------------------------

sub startPlayback()
    if m.promoted or m.closing then return
    if m.session = invalid or m.sessionId = "" then return
    if asString(m.session.id) <> m.sessionId then return
    if asString(m.session.state) <> "running" then return
    ensureVideoNode()
    if m.video = invalid then return
    base = ""
    cfg = m.top.config
    if cfg <> invalid and cfg.multiviewUrl <> invalid then base = cfg.multiviewUrl.Trim()
    while Right(base, 1) = "/"
        base = Left(base, Len(base) - 1)
    end while
    if base <> "" and Instr(1, base, "://") = 0 then base = "http://" + base

    node = createObject("roSGNode", "ContentNode")
    node.url = base + asString(m.session.playlistUrl)
    node.streamFormat = "hls"
    node.title = "Multiview"
    ' Do not mark live: Roku routes FF/RW to trickplay for live ContentNodes
    ' and MultiviewScreen almost never sees those keys. Same as sports direct play.
    m.video.content = node
    m.video.control = "play"
    m.playing = true
    if not m.switching then setStatus("Loading games...")
    restartStallTimer()
    ensureFocus()
end sub

' Soft stop — keeps the Video node. Prefer releaseVideo() before handing the
' decoder to VideoScreen (control=stop alone is not enough for sports HLS).
sub stopVideo()
    m.stallTimer.control = "stop"
    m.retryTimer.control = "stop"
    if m.video <> invalid then m.video.control = "stop"
    m.playing = false
end sub

' Tear the Video node out so the decoder actually releases for fullscreen.
sub releaseVideo()
    m.stallTimer.control = "stop"
    m.retryTimer.control = "stop"
    m.playing = false
    if m.video = invalid then return
    vid = m.video
    m.video = invalid
    vid.unobserveField("state")
    vid.unobserveField("availableAudioTracks")
    vid.control = "stop"
    vid.content = invalid
    parent = vid.getParent()
    if parent <> invalid then parent.removeChild(vid)
end sub

sub ensureVideoNode()
    if m.video <> invalid then return
    vid = createObject("roSGNode", "Video")
    vid.id = "video"
    vid.width = 1920
    vid.height = 1080
    vid.enableUI = false
    vid.focusable = false
    vid.notificationInterval = 1
    ' Keep overlays above the picture: insert under tileLayer
    insertAt = m.top.getChildCount()
    tileLayer = m.top.findNode("tileLayer")
    if tileLayer <> invalid then
        for i = 0 to m.top.getChildCount() - 1
            if m.top.getChild(i).isSameNode(tileLayer) then
                insertAt = i
                exit for
            end if
        end for
    end if
    m.top.insertChild(vid, insertAt)
    m.video = vid
    m.video.observeField("state", "onVideoState")
    m.video.observeField("availableAudioTracks", "onAudioTracks")
end sub

sub onVideoState()
    if m.video = invalid or m.promoted or m.closing then return
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
        ' A live mosaic never legitimately ends; retry quietly
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
    if m.promoted or m.closing then return
    if m.video <> invalid and m.video.state = "playing" then return
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
    if m.video = invalid then return
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

' Rotate which stream sits in each layout slot. FF/RW call this; taps within
' ~350ms coalesce into one PUT so two quick presses skip ahead by two.
sub rotateFeeds(delta as Integer)
    if m.session = invalid or m.session.order = invalid then return
    if m.session.order.count() < 2 then return

    base = m.pendingOrder
    if base = invalid then
        base = []
        for each stream in m.session.order
            base.push(Int(stream))
        end for
    end if
    m.pendingOrder = rotatedOrder(base, delta)
    m.focusAfterSwitch = 0
    print "[plexflix:multiview] rotate delta=" + StrI(delta).Trim() + " pending -> " + FormatJson(m.pendingOrder)

    ' While a mosaic restart is already in flight, just queue; onSettled flushes
    if m.switching then return
    m.rotateTimer.control = "stop"
    m.rotateTimer.duration = 0.35
    m.rotateTimer.control = "start"
end sub

function rotatedOrder(order as Object, delta as Integer) as Object
    n = order.count()
    out = []
    if n = 0 then return out
    steps = delta
    while steps < 0
        steps = steps + n
    end while
    steps = steps MOD n
    for i = 0 to n - 1
        out.push(Int(order[(i + steps) MOD n]))
    end for
    return out
end function

sub onRotateDebounced()
    if m.closing or m.pendingOrder = invalid then return
    if m.switching then return
    order = m.pendingOrder
    m.pendingOrder = invalid
    if m.session = invalid or m.session.order = invalid then return
    if order.count() <> m.session.order.count() then return
    unchanged = true
    for i = 0 to order.count() - 1
        if order[i] <> Int(m.session.order[i]) then
            unchanged = false
            exit for
        end if
    end for
    if unchanged then return
    requestUpdate({ order: order }, "Switching games...")
end sub

sub requestUpdate(payload as Object, message as String)
    if m.switching or m.sessionId = "" then return
    payload.id = m.sessionId
    m.switchMessage = message
    m.switching = true
    hideOverlay()
    setStatus(message)
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
        m.switching = false
        showNotice(err)
        return
    end if

    m.session = response.session
    hideOverlay()
    m.tileLayer.visible = false
    setStatus(m.switchMessage)
    ' ffmpeg restarts the mosaic; wait for the new arrangement through HLS
    m.settleTimer.control = "stop"
    m.settleTimer.duration = 7
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
    ' Always drop "Switching games…": the mosaic may still be buffering, and
    ' leaving the banner up forever made rotates look stuck.
    if m.video <> invalid and m.video.state = "playing" then
        clearStatus()
    else if m.notice = "" then
        setStatus("Loading games...")
    end if
    applyAudio()
    ' More FF/RW landed during the restart — send the coalesced order next
    if m.pendingOrder <> invalid then
        onRotateDebounced()
        return
    end if
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
    if tile = invalid or tile.stream = invalid then return
    index = Int(tile.stream)
    if index < 0 or index >= m.streams.count() then return
    stream = m.streams[index]
    ' Same vendored proxy path the mosaic uses — not the LAN :8787 URL, which
    ' races the in-container proxy and often dies with HTTP -1 on the Roku.
    url = feedPlayoutUrl(index)
    if url = "" then url = asString(stream.url)
    if url = "" then return

    ' Flag first so a sync stop/finished callback cannot start a reconnect
    m.promoted = true
    ' Keep polling: idle reap uses last_seen, and stopping the heartbeat
    ' deletes the session under the fullscreen player.
    hideOverlay()
    clearStatus()
    ' Free the decoder — stop alone leaves sports HLS holding it
    releaseVideo()

    format = asString(stream.streamFormat)
    if format = "" then format = "hls"
    print "[plexflix:multiview] promote stream=" + StrI(index).Trim() + " " + url
    m.top.playRequested = {
        title: asString(stream.title),
        description: asString(stream.league),
        mediaType: "sport",
        key: url,
        streamUrl: url,
        streamFormat: format,
        hdPosterUrl: asString(stream.hdPosterUrl),
        ratingKey: "",
        duration: 0,
        viewOffset: 0
    }
end sub

function feedPlayoutUrl(streamIndex as Integer) as String
    if m.sessionId = "" then return ""
    base = ""
    cfg = m.top.config
    if cfg <> invalid and cfg.multiviewUrl <> invalid then base = cfg.multiviewUrl.Trim()
    while Right(base, 1) = "/"
        base = Left(base, Len(base) - 1)
    end while
    if base = "" then return ""
    if Instr(1, base, "://") = 0 then base = "http://" + base
    return base + "/sessions/" + m.sessionId + "/feed/" + StrI(streamIndex).Trim() + "/index.m3u8"
end function

sub onResume()
    if m.top.resume <> true then return
    m.promoted = false
    m.playing = false
    ensureVideoNode()
    ensureFocus()
    ' While the fullscreen player was up the mosaic session can be reaped
    ' (idle) or still only "starting". Don't point Video at a stale playlistUrl.
    if m.sessionId = "" or m.session = invalid then
        setStatus("Starting multiview" + readySuffix())
        if m.sessionId = "" and not m.recreated then createSession()
        return
    end if
    setStatus("Loading games...")
    m.pollTimer.duration = 2
    m.pollTimer.control = "start"
    ' Immediate heartbeat: adoptSession starts playback once state=running
    onPollTimer()
    if m.session <> invalid and asString(m.session.id) = m.sessionId and asString(m.session.state) = "running" then
        startPlayback()
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
    layout = ""
    if m.session <> invalid then layout = layoutName(asString(m.session.layout))
    m.layoutLabel.text = layout
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
        if m.video <> invalid and m.video.state = "playing" and not m.switching then clearStatus()
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
    print "[plexflix:multiview] key=" + key
    ensureFocus()

    if key = "back" then
        closeScreen()
        return true
    end if

    if m.session = invalid or m.tiles.count() = 0 then return true

    ' FF/RW still land while a mosaic restart settles so rapid taps queue
    if m.switching then
        if key = "fastforward" then
            rotateFeeds(1)
        else if key = "rewind" then
            rotateFeeds(-1)
        end if
        return true
    end if

    if key = "up" or key = "down" or key = "left" or key = "right" then
        moveFocus(key)
    else if key = "OK" or key = "play" then
        promoteFocused()
    else if key = "options" then
        cycleLayout()
    else if key = "fastforward" then
        rotateFeeds(1)
    else if key = "rewind" then
        rotateFeeds(-1)
    else
        showOverlay()
    end if
    ' Everything is swallowed: Left in particular must not open the side nav
    return true
end function

sub onFocusedChild()
    if m.video = invalid then return
    child = m.top.focusedChild
    if child = invalid then return
    if child.isSameNode(m.video) then ensureFocus()
end sub

sub ensureFocus()
    if m.video = invalid then return
    m.video.focusable = false
    ' Always re-assert: hasFocus() is false while Video holds focus, and that
    ' is exactly when FF/RW never reach onKeyEvent
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
    m.rotateTimer.control = "stop"
    m.pendingOrder = invalid
    releaseVideo()
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
    m.statusLabel.text = message
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
