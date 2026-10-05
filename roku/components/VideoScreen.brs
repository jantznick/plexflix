sub init()
    m.video = m.top.findNode("video")
    m.statusLabel = m.top.findNode("statusLabel")
    m.spinner = m.top.findNode("spinner")

    m.controls = m.top.findNode("controls")
    m.scrim = m.top.findNode("scrim")
    m.titleLabel = m.top.findNode("titleLabel")
    m.subtitleLabel = m.top.findNode("subtitleLabel")
    m.track = m.top.findNode("track")
    m.fill = m.top.findNode("fill")
    m.thumb = m.top.findNode("thumb")
    m.elapsedLabel = m.top.findNode("elapsedLabel")
    m.endsAtLabel = m.top.findNode("endsAtLabel")
    m.remainingLabel = m.top.findNode("remainingLabel")
    m.buttonRow = m.top.findNode("buttonRow")

    m.castPanel = m.top.findNode("castPanel")
    m.castRow = m.top.findNode("castRow")

    m.picker = m.top.findNode("picker")
    m.pickerTitle = m.top.findNode("pickerTitle")
    m.pickerRowsHost = m.top.findNode("pickerRows")

    m.fade = m.top.findNode("fade")
    m.fadeInterp = m.top.findNode("fadeInterp")
    m.fade.observeField("state", "onFadeState")

    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "onHideTimer")
    m.seekTimer = m.top.findNode("seekTimer")
    m.seekTimer.observeField("fire", "onSeekCommit")
    m.reportTimer = m.top.findNode("reportTimer")
    m.reportTimer.observeField("fire", "onReportTimer")

    m.trackWidth = m.track.width

    ' hidden | scrubber | buttons | picker
    m.zone = "hidden"
    m.fadingOut = false

    m.item = invalid
    m.isLive = false
    m.duration = 0
    m.position = 0
    m.resumeAt = 0
    m.paused = false
    m.started = false
    m.scrobbled = false
    m.session = ""

    m.buttons = []
    m.buttonIndex = 0
    m.streams = invalid
    m.audioId = 0
    m.subtitleId = 0
    m.mediaIndex = 0

    m.pickerKind = ""
    m.pickerOptions = []
    m.pickerIndex = 0
    m.pickerTop = 0
    m.pickerRowNodes = []

    m.pendingSeek = invalid

    m.clock24 = (CreateObject("roDeviceInfo").GetClockFormat() = "24h")

    m.video.observeField("state", "onVideoState")
    m.video.observeField("position", "onPositionChange")
end sub

'--------------------------------------------------------------------
' Startup
'--------------------------------------------------------------------

sub onContentSet()
    item = m.top.content
    cfg = m.top.config
    if item = invalid or cfg = invalid then return

    m.item = item
    m.duration = Int(numberOf(item.duration) / 1000)
    m.resumeAt = Int(numberOf(item.viewOffset) / 1000)
    m.session = newSessionId()

    ' Live sports / direct URLs skip Plex transcoder
    mediaType = valueOrEmpty(item.mediaType)
    directUrl = ""
    if item.streamUrl <> invalid then directUrl = valueOrEmpty(item.streamUrl)
    if directUrl = "" and mediaType = "sport" then directUrl = valueOrEmpty(item.key)
    m.isLive = (mediaType = "livetv" or (directUrl <> "" and Left(directUrl, 4) = "http"))

    paintMeta()
    setStatus("Preparing " + valueOrEmpty(item.title) + "...")

    if directUrl <> "" and Left(directUrl, 4) = "http" then
        playDirect(directUrl, item)
        return
    end if

    ' Live TV channels: tune DVR then play session HLS
    if mediaType = "livetv" then
        setStatus("Tuning " + valueOrEmpty(item.title) + "...")
        m.task = createObject("roSGNode", "PlexTask")
        m.task.config = cfg
        m.task.action = "tuneLiveChannel"
        m.task.item = item
        m.task.observeField("response", "onStreamReady")
        m.task.control = "RUN"
        return
    end if

    requestStream(m.resumeAt)
    loadStreamOptions()
    loadCast()
end sub

sub requestStream(startAt as Integer)
    cfg = m.top.config
    if cfg = invalid or m.item = invalid then return

    m.startAt = startAt
    ' Seed the position so the first timeline report carries the resume point
    ' rather than the zero the stopped Video node is still showing
    m.position = startAt
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = cfg
    m.task.action = "streamUrl"
    m.task.item = {
        key: m.item.key,
        ratingKey: m.item.ratingKey,
        mediaIndex: m.mediaIndex,
        session: m.session
    }
    m.task.observeField("response", "onStreamReady")
    m.task.control = "RUN"
end sub

sub playDirect(url as String, item as Object)
    contentNode = createObject("roSGNode", "ContentNode")
    contentNode.url = url
    contentNode.title = valueOrEmpty(item.title)
    lowerUrl = LCase(url)
    if Right(lowerUrl, 5) = ".m3u8" or Instr(1, lowerUrl, "m3u8") > 0 then
        contentNode.streamFormat = "hls"
    else if Right(lowerUrl, 4) = ".mpd" then
        contentNode.streamFormat = "dash"
    else
        contentNode.streamFormat = "mp4"
    end if
    m.video.content = contentNode
    m.video.control = "play"
    clearStatus()
    m.top.setFocus(true)
end sub

sub onStreamReady()
    response = m.task.response
    if response = invalid or response.ok <> true or response.url = invalid or response.url = "" then
        err = "Playback failed"
        if response <> invalid and response.error <> invalid then err = response.error
        setStatus(err)
        return
    end if

    item = m.top.content
    contentNode = createObject("roSGNode", "ContentNode")
    contentNode.url = response.url
    contentNode.title = valueOrEmpty(item.title)
    contentNode.streamFormat = "hls"
    if m.duration > 0 then contentNode.length = m.duration
    ' The transcode playlist is always full length, so the start point is a
    ' seek inside it. That keeps Video.position equal to the media position.
    startAt = 0
    if m.startAt <> invalid then startAt = m.startAt
    if startAt > 0 then contentNode.playStart = startAt

    m.video.content = contentNode
    m.video.control = "play"
    clearStatus()
    m.top.setFocus(true)
end sub

'--------------------------------------------------------------------
' Playback state
'--------------------------------------------------------------------

sub onVideoState()
    state = m.video.state

    if state = "playing" then
        m.started = true
        m.paused = false
        clearStatus()
        paintButtons()
        reportProgress("playing")
        m.reportTimer.control = "start"
        if m.zone <> "hidden" and m.zone <> "picker" then restartHideTimer()
    else if state = "paused" then
        m.paused = true
        paintButtons()
        reportProgress("paused")
        ' Pausing is the cue to show the panel and leave it up
        showControls(activeZone())
        m.hideTimer.control = "stop"
    else if state = "buffering" then
        if not m.started then setStatus("Buffering...")
    else if state = "error" then
        m.reportTimer.control = "stop"
        setStatus("Video error — try another title or check Plex transcoder")
    else if state = "finished" then
        m.reportTimer.control = "stop"
        sendPlaybackActions([scrobbleAction(), releaseAction()])
        m.top.closed = true
    end if
end sub

sub onPositionChange()
    m.position = Int(m.video.position)
    if m.pendingSeek = invalid and m.controls.visible then paintScrubber(m.position)
end sub

sub onReportTimer()
    if m.paused then
        reportProgress("paused")
    else
        reportProgress("playing")
    end if
end sub

sub togglePlayPause()
    if m.paused then
        m.video.control = "resume"
    else
        m.video.control = "pause"
    end if
end sub

sub restart()
    m.pendingSeek = invalid
    if m.isLive then return
    m.video.seek = 0
    if m.paused then m.video.control = "resume"
end sub

'--------------------------------------------------------------------
' Progress reporting
'--------------------------------------------------------------------

sub reportProgress(state as String)
    action = timelineAction(state)
    if action = invalid then return
    sendPlaybackActions([action])
end sub

function timelineAction(state as String) as Object
    if m.isLive or m.item = invalid then return invalid
    ratingKey = valueOrEmpty(m.item.ratingKey)
    key = valueOrEmpty(m.item.key)
    if ratingKey = "" or key = "" then return invalid

    return {
        action: "reportProgress",
        item: {
            ratingKey: ratingKey,
            key: key,
            state: state,
            time: m.position * 1000,
            duration: m.duration * 1000
        }
    }
end function

function scrobbleAction() as Object
    if m.isLive or m.item = invalid or m.scrobbled then return invalid
    ratingKey = valueOrEmpty(m.item.ratingKey)
    if ratingKey = "" then return invalid

    m.scrobbled = true
    return { action: "scrobble", item: { ratingKey: ratingKey } }
end function

function releaseAction() as Object
    if m.session = "" then return invalid
    session = m.session
    m.session = ""
    return { action: "stopTranscode", item: { session: session } }
end function

' One field write per moment: two writes in the same call could be coalesced
' into a single notification and lose whichever came first
sub sendPlaybackActions(actions as Object)
    wanted = []
    for each action in actions
        if action <> invalid then wanted.push(action)
    end for
    if wanted.count() = 0 then return
    m.top.playbackReport = { actions: wanted }
end sub

'--------------------------------------------------------------------
' Stream options
'--------------------------------------------------------------------

sub loadStreamOptions()
    if m.item = invalid then return
    ratingKey = valueOrEmpty(m.item.ratingKey)
    if ratingKey = "" then return

    m.streamTask = createObject("roSGNode", "PlexTask")
    m.streamTask.config = m.top.config
    m.streamTask.action = "mediaStreams"
    m.streamTask.item = { ratingKey: ratingKey }
    m.streamTask.observeField("response", "onStreamOptions")
    m.streamTask.control = "RUN"
end sub

sub onStreamOptions()
    response = m.streamTask.response
    if response = invalid or response.ok <> true then return

    m.streams = response
    m.audioId = selectedId(response.audio)
    m.subtitleId = selectedId(response.subtitles)
    paintButtons()
end sub

function selectedId(options as Object) as Integer
    if options = invalid then return 0
    for each option in options
        if option.selected = true then return option.id
    end for
    return 0
end function

sub applyStreamChoice(kind as String, option as Object)
    if option = invalid then return

    if kind = "version" then
        if option.mediaIndex = m.mediaIndex then return
        m.mediaIndex = option.mediaIndex
        restartStream("Switching version...")
        return
    end if

    if m.streams = invalid then return
    partId = valueOrEmpty(m.streams.partId)
    if partId = "" then return

    payload = { partId: partId }
    if kind = "audio" then
        if option.id = m.audioId then return
        m.audioId = option.id
        payload.audioStreamID = option.id
    else
        if option.id = m.subtitleId then return
        m.subtitleId = option.id
        payload.subtitleStreamID = option.id
    end if

    markSelected(kind, option.id)

    message = "Switching audio..."
    if kind = "subtitle" then message = "Switching subtitles..."
    beginRestart(message)

    m.selectTask = createObject("roSGNode", "PlexTask")
    m.selectTask.config = m.top.config
    m.selectTask.action = "selectStreams"
    m.selectTask.item = payload
    m.selectTask.observeField("response", "onStreamSelected")
    m.selectTask.control = "RUN"
end sub

sub markSelected(kind as String, id as Integer)
    if m.streams = invalid then return
    options = m.streams.audio
    if kind = "subtitle" then options = m.streams.subtitles
    if options = invalid then return
    for each option in options
        option.selected = (option.id = id)
    end for
end sub

sub onStreamSelected()
    ' The transcoder has to be rebuilt either way: a failed PUT just means the
    ' old track comes back, so resume from the same spot regardless
    restartStream("")
end sub

sub beginRestart(message as String)
    m.restartAt = m.position
    m.video.control = "stop"
    m.reportTimer.control = "stop"
    hideControls()
    if message <> "" then setStatus(message)
end sub

sub restartStream(message as String)
    if message <> "" then beginRestart(message)
    sendPlaybackActions([releaseAction()])
    m.session = newSessionId()
    resumeAt = 0
    if m.restartAt <> invalid then resumeAt = m.restartAt
    requestStream(resumeAt)
end sub

'--------------------------------------------------------------------
' Cast peek
'--------------------------------------------------------------------

sub loadCast()
    if m.item = invalid then return
    ratingKey = valueOrEmpty(m.item.ratingKey)
    if ratingKey = "" then return

    m.castTask = createObject("roSGNode", "PlexTask")
    m.castTask.config = m.top.config
    m.castTask.action = "extras"
    m.castTask.item = { ratingKey: ratingKey }
    m.castTask.observeField("response", "onCastLoaded")
    m.castTask.control = "RUN"
end sub

sub onCastLoaded()
    response = m.castTask.response
    if response = invalid or response.ok <> true then return
    cast = response.cast
    if cast = invalid or cast.count() = 0 then return

    maxShown = 7
    if cast.count() < maxShown then maxShown = cast.count()
    posterW = 94
    posterH = 141
    gap = 26

    while m.castRow.getChildCount() > 0
        m.castRow.removeChildIndex(0)
    end while

    for i = 0 to maxShown - 1
        member = cast[i]
        entry = m.castRow.createChild("Group")
        entry.translation = [i * (posterW + gap), 0]

        poster = entry.createChild("Poster")
        poster.width = posterW
        poster.height = posterH
        poster.loadDisplayMode = "scaleToZoom"
        poster.failedBitmapUri = "pkg:/images/poster_placeholder.png"
        poster.uri = valueOrEmpty(member.hdPosterUrl)
        if poster.uri = "" then poster.uri = "pkg:/images/poster_placeholder.png"

        name = entry.createChild("Label")
        name.width = posterW
        name.height = 38
        name.translation = [0, posterH + 8]
        name.wrap = true
        name.maxLines = 2
        name.color = "0xD8D8E0"
        name.text = valueOrEmpty(member.shortTitle)
        if name.text = "" then name.text = valueOrEmpty(member.title)
        font = name.createChild("Font")
        font.uri = "pkg:/fonts/Outfit-Medium.ttf"
        font.size = 15
    end for

    m.castPanel.visible = true
end sub

'--------------------------------------------------------------------
' Control panel painting
'--------------------------------------------------------------------

sub paintMeta()
    if m.item = invalid then return

    headline = valueOrEmpty(m.item.shortTitle)
    if headline = "" then headline = valueOrEmpty(m.item.title)
    context = ""

    if valueOrEmpty(m.item.mediaType) = "episode" then
        show = valueOrEmpty(m.item.grandparentTitle)
        season = valueOrEmpty(m.item.parentIndex)
        episode = valueOrEmpty(m.item.index)
        if season <> "" and episode <> "" then
            context = "S" + season + " · E" + episode
        end if
        if show <> "" then
            if context <> "" then context = show + "  ·  " + context else context = show
        end if
    else
        bits = []
        year = valueOrEmpty(m.item.year)
        if year <> "" then bits.push(year)
        contentRating = valueOrEmpty(m.item.contentRating)
        if contentRating <> "" then bits.push(contentRating)
        context = joinWith(bits, "  ·  ")
    end if

    m.titleLabel.text = headline
    m.subtitleLabel.text = context

    scrubbable = (not m.isLive and m.duration > 0)
    m.track.visible = scrubbable
    m.fill.visible = scrubbable
    m.thumb.visible = scrubbable
    m.elapsedLabel.visible = scrubbable
    m.remainingLabel.visible = scrubbable
    m.endsAtLabel.visible = scrubbable
end sub

sub paintScrubber(atSeconds as Integer)
    if m.duration <= 0 or m.isLive then return

    pct = atSeconds / m.duration
    if pct < 0 then pct = 0
    if pct > 1 then pct = 1

    m.fill.width = m.trackWidth * pct
    m.thumb.translation = [m.track.translation[0] + m.trackWidth * pct - 4, m.thumb.translation[1]]

    remaining = m.duration - atSeconds
    if remaining < 0 then remaining = 0
    m.elapsedLabel.text = formatRuntime(atSeconds)
    m.remainingLabel.text = "-" + formatRuntime(remaining)
    m.endsAtLabel.text = endsAtText(remaining)
end sub

' "Ends at 10:45 PM" — the one number you actually want when deciding
' whether to start another episode
function endsAtText(remainingSeconds as Integer) as String
    if remainingSeconds <= 0 then return ""

    finish = CreateObject("roDateTime")
    finish.FromSeconds(finish.AsSeconds() + remainingSeconds)
    ' ToLocalTime shifts in place, so it must only ever be called once
    finish.ToLocalTime()

    return "Ends at " + clockTime(finish.GetHours(), finish.GetMinutes(), m.clock24)
end function

function clockTime(hours as Integer, minutes as Integer, use24 as Boolean) as String
    if use24 then return pad2(hours) + ":" + pad2(minutes)

    suffix = " AM"
    if hours >= 12 then suffix = " PM"
    display = hours MOD 12
    if display = 0 then display = 12
    return StrI(display).Trim() + ":" + pad2(minutes) + suffix
end function

function formatRuntime(totalSeconds as Integer) as String
    if totalSeconds < 0 then totalSeconds = 0
    hours = Int(totalSeconds / 3600)
    minutes = Int((totalSeconds - hours * 3600) / 60)
    seconds = totalSeconds - hours * 3600 - minutes * 60
    if hours > 0 then return StrI(hours).Trim() + ":" + pad2(minutes) + ":" + pad2(seconds)
    return StrI(minutes).Trim() + ":" + pad2(seconds)
end function

function pad2(value as Integer) as String
    out = StrI(value).Trim()
    if Len(out) < 2 then return "0" + out
    return out
end function

sub paintButtons()
    specs = []
    if m.paused then
        specs.push({ id: "play", text: "Play" })
    else
        specs.push({ id: "play", text: "Pause" })
    end if
    if not m.isLive then specs.push({ id: "restart", text: "Restart" })
    if m.streams <> invalid then
        if m.streams.audio <> invalid and m.streams.audio.count() > 1 then
            specs.push({ id: "audio", text: "Audio" })
        end if
        if m.streams.subtitles <> invalid and m.streams.subtitles.count() > 1 then
            specs.push({ id: "subtitle", text: "Subtitles" })
        end if
        if m.streams.versions <> invalid and m.streams.versions.count() > 1 then
            specs.push({ id: "version", text: "Version" })
        end if
    end if

    rebuildButtons(specs)
    if m.buttonIndex >= m.buttons.count() then m.buttonIndex = 0
    paintButtonFocus()
end sub

sub rebuildButtons(specs as Object)
    ' Only tear the row down when the set actually changed: this runs on every
    ' play/pause flip and rebuilding nodes mid-animation looks like a flicker
    reusable = (m.buttons.count() = specs.count())
    if reusable then
        for i = 0 to specs.count() - 1
            if m.buttons[i].id <> specs[i].id then
                reusable = false
                exit for
            end if
        end for
    end if

    if reusable then
        for i = 0 to specs.count() - 1
            m.buttons[i].label.text = specs[i].text
        end for
        return
    end if

    while m.buttonRow.getChildCount() > 0
        m.buttonRow.removeChildIndex(0)
    end while
    m.buttons = []

    x = 0
    for each spec in specs
        width = 56 + Len(spec.text) * 13
        group = m.buttonRow.createChild("Group")
        group.translation = [x, 0]

        bg = group.createChild("Rectangle")
        bg.width = width
        bg.height = 52
        bg.color = "0x2A2A32"

        label = group.createChild("Label")
        label.width = width
        label.height = 52
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.text = spec.text
        font = label.createChild("Font")
        font.uri = "pkg:/fonts/Outfit-Medium.ttf"
        font.size = 22

        m.buttons.push({ id: spec.id, bg: bg, label: label })
        x = x + width + 16
    end for
end sub

sub paintButtonFocus()
    for i = 0 to m.buttons.count() - 1
        button = m.buttons[i]
        if m.zone = "buttons" and i = m.buttonIndex then
            button.bg.color = "0xFFFFFF"
            button.label.color = "0x111118"
        else
            button.bg.color = "0x2A2A32"
            button.label.color = "0xFFFFFF"
        end if
    end for

    highlight = "0x45454F"
    if m.zone = "scrubber" then highlight = "0x6E6E7A"
    m.track.color = highlight
end sub

'--------------------------------------------------------------------
' Show / hide
'--------------------------------------------------------------------

sub showControls(zone as String)
    m.zone = zone
    paintScrubber(m.position)
    paintButtons()
    paintButtonFocus()

    if m.controls.opacity < 1.0 or m.fadingOut then
        m.fadingOut = false
        m.controls.visible = true
        m.fadeInterp.keyValue = [m.controls.opacity, 1.0]
        m.fade.control = "start"
    end if

    if m.paused then m.hideTimer.control = "stop" else restartHideTimer()
end sub

sub hideControls()
    m.zone = "hidden"
    m.hideTimer.control = "stop"
    if not m.controls.visible then return
    m.fadingOut = true
    m.fadeInterp.keyValue = [m.controls.opacity, 0.0]
    m.fade.control = "start"
end sub

sub onFadeState()
    if m.fade.state = "stopped" and m.fadingOut then
        m.fadingOut = false
        m.controls.visible = false
    end if
end sub

sub restartHideTimer()
    m.hideTimer.control = "stop"
    m.hideTimer.control = "start"
end sub

sub onHideTimer()
    if m.paused or m.zone = "picker" then return
    hideControls()
end sub

'--------------------------------------------------------------------
' Seeking
'--------------------------------------------------------------------

sub nudgeSeek(deltaSeconds as Integer)
    if m.isLive or m.duration <= 0 then return

    base = m.position
    if m.pendingSeek <> invalid then base = m.pendingSeek
    target = base + deltaSeconds
    if target < 0 then target = 0
    if target > m.duration - 2 then target = m.duration - 2
    if target < 0 then target = 0

    m.pendingSeek = target
    paintScrubber(target)

    ' Let a run of presses settle before asking the transcoder for a new spot
    m.seekTimer.control = "stop"
    m.seekTimer.control = "start"
end sub

sub onSeekCommit()
    if m.pendingSeek = invalid then return
    target = m.pendingSeek
    m.pendingSeek = invalid
    m.video.seek = target
    reportProgress("playing")
end sub

'--------------------------------------------------------------------
' Pickers
'--------------------------------------------------------------------

sub openPicker(kind as String)
    if m.streams = invalid then return

    options = []
    title = ""
    current = 0
    if kind = "audio" then
        options = m.streams.audio
        title = "Audio"
        current = m.audioId
    else if kind = "subtitle" then
        options = m.streams.subtitles
        title = "Subtitles"
        current = m.subtitleId
    else
        options = m.streams.versions
        title = "Version"
    end if
    if options = invalid or options.count() = 0 then return

    m.pickerKind = kind
    m.pickerOptions = options
    m.pickerTitle.text = title

    m.pickerIndex = 0
    for i = 0 to options.count() - 1
        if kind = "version" then
            if options[i].mediaIndex = m.mediaIndex then m.pickerIndex = i
        else if options[i].id = current then
            m.pickerIndex = i
        end if
    end for

    m.pickerTop = 0
    if m.pickerIndex >= pickerWindow() then m.pickerTop = m.pickerIndex - pickerWindow() + 1

    m.zone = "picker"
    m.hideTimer.control = "stop"
    m.picker.visible = true
    paintPicker()
end sub

function pickerWindow() as Integer
    return 8
end function

sub paintPicker()
    rowHeight = 56
    visible = pickerWindow()
    if m.pickerOptions.count() < visible then visible = m.pickerOptions.count()

    ensurePickerRows(visible)

    for i = 0 to m.pickerRowNodes.count() - 1
        row = m.pickerRowNodes[i]
        if i >= visible then
            row.group.visible = false
        else
            index = m.pickerTop + i
            option = m.pickerOptions[index]
            row.group.visible = true
            row.group.translation = [0, i * rowHeight]
            row.label.text = valueOrEmpty(option.label)
            row.tick.visible = isActiveOption(option)
            if index = m.pickerIndex then
                row.bg.visible = true
                row.label.color = "0x111118"
            else
                row.bg.visible = false
                row.label.color = "0xE4E4EC"
            end if
        end if
    end for
end sub

function isActiveOption(option as Object) as Boolean
    if m.pickerKind = "version" then return option.mediaIndex = m.mediaIndex
    return option.selected = true
end function

sub ensurePickerRows(count as Integer)
    while m.pickerRowNodes.count() < count
        group = m.pickerRowsHost.createChild("Group")

        bg = group.createChild("Rectangle")
        bg.width = 680
        bg.height = 52
        bg.color = "0xFFFFFF"
        bg.visible = false

        label = group.createChild("Label")
        label.width = 580
        label.height = 52
        label.translation = [20, 0]
        label.vertAlign = "center"
        font = label.createChild("Font")
        font.uri = "pkg:/fonts/Outfit-Medium.ttf"
        font.size = 24

        tick = group.createChild("Poster")
        tick.width = 26
        tick.height = 26
        tick.translation = [628, 13]
        tick.uri = "pkg:/images/watched_check.png"
        tick.visible = false

        m.pickerRowNodes.push({ group: group, bg: bg, label: label, tick: tick })
    end while
end sub

sub closePicker()
    m.picker.visible = false
    m.pickerKind = ""
    m.pickerOptions = []
    showControls("buttons")
end sub

sub movePicker(delta as Integer)
    if m.pickerOptions.count() = 0 then return

    target = m.pickerIndex + delta
    ' Deliberately clamped: a wrapping option list is disorienting
    if target < 0 then target = 0
    if target > m.pickerOptions.count() - 1 then target = m.pickerOptions.count() - 1
    m.pickerIndex = target

    if m.pickerIndex < m.pickerTop then m.pickerTop = m.pickerIndex
    if m.pickerIndex > m.pickerTop + pickerWindow() - 1 then
        m.pickerTop = m.pickerIndex - pickerWindow() + 1
    end if
    paintPicker()
end sub

sub choosePickerOption()
    if m.pickerOptions.count() = 0 then return
    option = m.pickerOptions[m.pickerIndex]
    kind = m.pickerKind
    m.picker.visible = false
    m.pickerKind = ""
    m.pickerOptions = []
    m.zone = "hidden"
    applyStreamChoice(kind, option)
end sub

'--------------------------------------------------------------------
' Remote
'--------------------------------------------------------------------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" then
        if m.zone = "picker" then
            closePicker()
            return true
        end if
        stopAndClose()
        return true
    end if

    if m.zone = "picker" then
        if key = "up" then
            movePicker(-1)
            return true
        else if key = "down" then
            movePicker(1)
            return true
        else if key = "OK" then
            choosePickerOption()
            return true
        else if key = "left" then
            closePicker()
            return true
        end if
        return true
    end if

    if key = "play" or key = "pause" then
        togglePlayPause()
        showControls(activeZone())
        return true
    end if

    if key = "rewind" then
        showControls(activeZone())
        nudgeSeek(-30)
        return true
    else if key = "fastforward" then
        showControls(activeZone())
        nudgeSeek(30)
        return true
    end if

    if m.zone = "hidden" then
        if key = "up" or key = "down" or key = "OK" or key = "left" or key = "right" then
            showControls("scrubber")
            return true
        end if
        return false
    end if

    if m.zone = "scrubber" then
        if key = "left" then
            restartHideTimer()
            nudgeSeek(-10)
            return true
        else if key = "right" then
            restartHideTimer()
            nudgeSeek(10)
            return true
        else if key = "down" then
            if m.buttons.count() > 0 then showControls("buttons")
            return true
        else if key = "up" then
            hideControls()
            return true
        else if key = "OK" then
            togglePlayPause()
            return true
        end if
        return true
    end if

    if m.zone = "buttons" then
        if key = "left" then
            moveButton(-1)
            return true
        else if key = "right" then
            moveButton(1)
            return true
        else if key = "up" then
            showControls("scrubber")
            return true
        else if key = "down" then
            hideControls()
            return true
        else if key = "OK" then
            activateButton()
            return true
        end if
        return true
    end if

    return false
end function

function activeZone() as String
    if m.zone = "hidden" then return "scrubber"
    return m.zone
end function

sub moveButton(delta as Integer)
    if m.buttons.count() = 0 then return
    target = m.buttonIndex + delta
    if target < 0 then target = 0
    if target > m.buttons.count() - 1 then target = m.buttons.count() - 1
    m.buttonIndex = target
    paintButtonFocus()
    restartHideTimer()
end sub

sub activateButton()
    if m.buttons.count() = 0 then return
    id = m.buttons[m.buttonIndex].id
    restartHideTimer()

    if id = "play" then
        togglePlayPause()
    else if id = "restart" then
        restart()
    else
        openPicker(id)
    end if
end sub

'--------------------------------------------------------------------
' Teardown
'--------------------------------------------------------------------

sub onCloseRequested()
    if m.top.close = true then
        stopAndClose()
    end if
end sub

sub stopAndClose()
    m.reportTimer.control = "stop"
    m.hideTimer.control = "stop"
    m.seekTimer.control = "stop"
    sendPlaybackActions([timelineAction("stopped"), releaseAction()])
    if m.video <> invalid then m.video.control = "stop"
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
end sub

sub clearStatus()
    m.statusLabel.visible = false
    m.spinner.control = "stop"
    m.spinner.visible = false
end sub

function newSessionId() as String
    return CreateObject("roDeviceInfo").GetRandomUUID()
end function

function numberOf(value as Dynamic) as Integer
    if value = invalid then return 0
    valueType = type(value)
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return value
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        return Int(value)
    end if
    if valueType = "String" or valueType = "roString" then
        if value = "" then return 0
        return Int(Val(value))
    end if
    return 0
end function

function joinWith(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function

function valueOrEmpty(value as Dynamic) as String
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
