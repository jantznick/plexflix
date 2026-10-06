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

    m.previewFrame = m.top.findNode("previewFrame")
    m.previewImage = m.top.findNode("previewImage")

    m.skipPill = m.top.findNode("skipPill")
    m.skipLabel = m.top.findNode("skipLabel")

    m.castModal = m.top.findNode("castModal")
    m.castModalPhoto = m.top.findNode("castModalPhoto")
    m.castModalName = m.top.findNode("castModalName")
    m.castModalRole = m.top.findNode("castModalRole")
    m.castModalMeta = m.top.findNode("castModalMeta")
    m.castModalBio = m.top.findNode("castModalBio")
    m.castModalKnownFor = m.top.findNode("castModalKnownFor")
    m.castModalSpinner = m.top.findNode("castModalSpinner")

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

    ' hidden | cast | scrubber | buttons | picker | castModal
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

    m.cast = []
    m.castNodes = []
    m.castIndex = 0
    m.castResumeOnClose = false

    m.markers = []
    m.activeMarker = invalid

    m.previewBase = ""
    m.previewAt = -1

    m.pendingSeek = invalid

    m.clock24 = (CreateObject("roDeviceInfo").GetClockFormat() = "24h")

    ' Belt-and-suspenders with focusable="false" in XML: some firmware still
    ' hands focus to Video when control="play" flips it to buffering/playing.
    m.video.focusable = false
    m.video.observeField("state", "onVideoState")
    m.video.observeField("position", "onPositionChange")
    m.top.observeField("focusedChild", "onFocusedChild")
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
    logPlayback("direct url " + url)
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
    ensurePlayerFocus()
end sub

sub onStreamReady()
    response = m.task.response
    if response = invalid or response.ok <> true or response.url = invalid or response.url = "" then
        err = "Playback failed"
        if response <> invalid and response.error <> invalid then err = response.error
        setStatus(err)
        ensurePlayerFocus()
        return
    end if

    item = m.top.content
    logPlayback("stream url " + response.url)
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
    ensurePlayerFocus()
end sub

'--------------------------------------------------------------------
' Playback state
'--------------------------------------------------------------------

sub onFocusedChild()
    ' If anything under this screen (especially Video) grabs focus, take it
    ' back so onKeyEvent keeps owning the remote.
    child = m.top.focusedChild
    if child = invalid then return
    if child.isSameNode(m.video) then
        ensurePlayerFocus()
    end if
end sub

sub ensurePlayerFocus()
    m.video.focusable = false
    ' Always re-assert: hasFocus() is false while a child holds focus, and that
    ' is exactly the broken state we are trying to leave.
    m.top.setFocus(true)
end sub

sub onVideoState()
    state = m.video.state
    logPlayback("state=" + state + " position=" + StrI(m.position).Trim() + " duration=" + StrI(m.duration).Trim())

    ' Reclaim focus on every live playback transition — Video likes to take it
    ' the moment a stream actually starts.
    if state = "playing" or state = "paused" or state = "buffering" then
        ensurePlayerFocus()
    end if

    if state = "playing" then
        m.started = true
        m.paused = false
        clearStatus()
        paintButtons()
        reportProgress("playing")
        m.reportTimer.control = "start"
        if m.zone <> "hidden" and m.zone <> "picker" and m.zone <> "castModal" then restartHideTimer()
    else if state = "paused" then
        m.paused = true
        paintButtons()
        reportProgress("paused")
        m.hideTimer.control = "stop"
        ' Pausing is the cue to show the panel and leave it up, unless the pause
        ' came from opening the cast modal, which owns the screen already
        if m.zone <> "castModal" then showControls(activeZone())
    else if state = "buffering" then
        if not m.started then setStatus("Buffering...")
    else if state = "error" then
        m.reportTimer.control = "stop"
        sendPlaybackActions([releaseAction()])
        showPlaybackError("Playback failed")
        ensurePlayerFocus()
    else if state = "finished" then
        m.reportTimer.control = "stop"
        if playedToEnd() then
            sendPlaybackActions([scrobbleAction(), releaseAction()])
            m.top.closed = true
        else
            ' Finishing without having played is a failure, not a completed
            ' title. Closing here would hide the reason, and scrobbling would
            ' mark something watched that never rendered a frame.
            sendPlaybackActions([releaseAction()])
            showPlaybackError("Stream ended before it played")
            ensurePlayerFocus()
        end if
    end if
end sub

' Plex's own clients treat the last tenth as "watched", and anything short of
' that as a stream that stopped early
function playedToEnd() as Boolean
    if not m.started then return false
    if m.duration <= 0 then return true
    return m.position >= Int(m.duration * 0.9)
end function

sub showPlaybackError(reason as String)
    detail = videoErrorDetail()
    message = reason
    if detail <> "" then message = message + Chr(10) + detail
    logPlayback("ERROR " + reason + " " + detail)

    hideControls()
    m.spinner.control = "stop"
    m.spinner.visible = false
    m.statusLabel.visible = true
    m.statusLabel.text = message + Chr(10) + "Press Back to return"
end sub

' Whatever the firmware is willing to tell us about why a stream died. Worth
' having on screen: without it a failure is indistinguishable from a title that
' simply ended.
function videoErrorDetail() as String
    bits = []

    code = m.video.errorCode
    if code <> invalid and code <> 0 then bits.push("code " + StrI(code).Trim())

    msg = valueOrEmpty(m.video.errorMsg)
    if msg <> "" then bits.push(msg)

    detail = valueOrEmpty(m.video.errorStr)
    if detail <> "" and detail <> msg then bits.push(detail)

    info = m.video.errorInfo
    if info <> invalid then
        status = valueOrEmpty(info.httpStatus)
        if status <> "" and status <> "0" then bits.push("HTTP " + status)
        dbg = valueOrEmpty(info.dbgmsg)
        if dbg <> "" and dbg <> detail then bits.push(dbg)
    end if

    if bits.count() = 0 then return ""
    return joinWith(bits, " · ")
end function

' Tagged so it can be picked out of the debug console on port 8085
sub logPlayback(message as String)
    print "[plexflix:player] " + message
end sub

sub onPositionChange()
    m.position = Int(m.video.position)
    if m.pendingSeek = invalid and m.controls.visible then paintScrubber(m.position)
    refreshMarker()
end sub

'--------------------------------------------------------------------
' Intro / credits / commercial markers
'--------------------------------------------------------------------

sub refreshMarker()
    marker = markerAt(m.position)
    if marker = invalid and m.activeMarker = invalid then return

    changed = true
    if marker <> invalid and m.activeMarker <> invalid then
        changed = (marker.startAt <> m.activeMarker.startAt)
    end if

    m.activeMarker = marker
    if marker <> invalid then m.skipLabel.text = marker.label
    paintSkip()
    ' The skip sits at the front of the button row, so the row changes shape
    if changed and m.controls.visible then paintButtons()
end sub

function markerAt(atSeconds as Integer) as Object
    if m.markers = invalid or m.markers.count() = 0 then return invalid
    atMs = atSeconds * 1000

    for each marker in m.markers
        ' Stop offering the skip right at the boundary, where it would be a no-op
        if atMs >= marker.startAt and atMs < marker.endAt - 1000 then return marker
    end for
    return invalid
end function

sub paintSkip()
    ' Hidden whenever the panel is up: the button row carries the skip there,
    ' and the pill would land on top of the title
    m.skipPill.visible = (m.activeMarker <> invalid and not m.controls.visible and m.zone = "hidden")
end sub

sub skipMarker()
    if m.activeMarker = invalid then return

    target = Int(m.activeMarker.endAt / 1000)
    if m.duration > 0 and target > m.duration - 2 then target = m.duration - 2
    if target < 0 then target = 0

    m.activeMarker = invalid
    paintSkip()

    m.pendingSeek = invalid
    m.seekTimer.control = "stop"
    hidePreview()
    m.video.seek = target
    m.position = target
    if m.controls.visible then
        paintScrubber(target)
        paintButtons()
    end if
end sub

'--------------------------------------------------------------------
' Scrubbing preview thumbnails
'--------------------------------------------------------------------

sub showPreview(atSeconds as Integer)
    if m.previewBase = "" or m.isLive then return

    ' Plex builds the BIF index at a coarse interval, so rounding keeps this to
    ' one request per bucket instead of one per keypress
    bucket = Int(atSeconds / 5) * 5
    if bucket <> m.previewAt then
        m.previewAt = bucket
        token = ""
        if m.top.config <> invalid then token = valueOrEmpty(m.top.config.token)
        m.previewImage.uri = m.previewBase + StrI(bucket * 1000).Trim() + "?X-Plex-Token=" + token
    end if

    pct = 0
    if m.duration > 0 then pct = atSeconds / m.duration
    if pct < 0 then pct = 0
    if pct > 1 then pct = 1

    left = m.track.translation[0] + m.trackWidth * pct - m.previewFrame.width / 2
    minLeft = m.track.translation[0]
    maxLeft = minLeft + m.trackWidth - m.previewFrame.width
    if left < minLeft then left = minLeft
    if left > maxLeft then left = maxLeft

    m.previewFrame.translation = [left, 691]
    m.previewImage.translation = [left + 3, 694]
    m.previewFrame.visible = true
    m.previewImage.visible = true

    ' The preview sits over the title strip and the left end of the cast row,
    ' so both step aside for as long as it is up
    m.titleLabel.visible = false
    m.subtitleLabel.visible = false
    m.castPanel.visible = false
end sub

sub hidePreview()
    if m.previewFrame = invalid then return
    m.previewFrame.visible = false
    m.previewImage.visible = false
    m.titleLabel.visible = true
    m.subtitleLabel.visible = true
    m.castPanel.visible = (m.castNodes.count() > 0)
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

    m.markers = response.markers
    if m.markers = invalid then m.markers = []
    m.previewBase = valueOrEmpty(response.previewUrlBase)

    refreshMarker()
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
        ' A different version is a different file: its part id, track ids and
        ' preview index all have to be read again
        m.previewBase = ""
        m.previewAt = -1
        hidePreview()
        loadStreamOptions()
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
    m.cast = []
    m.castNodes = []

    for i = 0 to maxShown - 1
        member = cast[i]
        entry = m.castRow.createChild("Group")
        entry.translation = [i * (posterW + gap), 0]

        ring = entry.createChild("Rectangle")
        ring.width = posterW + 8
        ring.height = posterH + 8
        ring.translation = [-4, -4]
        ring.color = "0xFFFFFF"
        ring.visible = false

        poster = entry.createChild("Poster")
        poster.width = posterW
        poster.height = posterH
        poster.loadDisplayMode = "scaleToZoom"
        poster.failedBitmapUri = "pkg:/images/poster_placeholder.png"
        poster.uri = valueOrEmpty(member.hdPosterUrl)
        if poster.uri = "" then poster.uri = "pkg:/images/poster_placeholder.png"
        poster.opacity = 0.78

        name = entry.createChild("Label")
        name.width = posterW
        name.height = 38
        name.translation = [0, posterH + 8]
        name.wrap = true
        name.maxLines = 2
        name.color = "0x9A9AA4"
        name.text = valueOrEmpty(member.shortTitle)
        if name.text = "" then name.text = valueOrEmpty(member.title)
        font = name.createChild("Font")
        font.uri = "pkg:/fonts/Outfit-Medium.ttf"
        font.size = 15

        m.cast.push(member)
        m.castNodes.push({ ring: ring, poster: poster, label: name })
    end for

    m.castPanel.visible = true
    paintCastFocus()
end sub

sub paintCastFocus()
    for i = 0 to m.castNodes.count() - 1
        node = m.castNodes[i]
        focused = (m.zone = "cast" and i = m.castIndex)
        node.ring.visible = focused
        if focused then
            node.poster.opacity = 1.0
            node.label.color = "0xFFFFFF"
        else
            node.poster.opacity = 0.78
            node.label.color = "0x9A9AA4"
        end if
    end for
end sub

sub moveCast(delta as Integer)
    if m.castNodes.count() = 0 then return
    target = m.castIndex + delta
    if target < 0 then target = 0
    if target > m.castNodes.count() - 1 then target = m.castNodes.count() - 1
    m.castIndex = target
    paintCastFocus()
    restartHideTimer()
end sub

'--------------------------------------------------------------------
' Cast detail without leaving playback
'--------------------------------------------------------------------

sub openCastModal()
    if m.castIndex >= m.cast.count() then return
    member = m.cast[m.castIndex]

    ' Remember whether we were the ones who paused, so closing restores it
    m.castResumeOnClose = not m.paused

    ' Zone first: the pause below comes back as a state change, and that handler
    ' needs to already know the modal owns the screen
    m.zone = "castModal"
    m.hideTimer.control = "stop"
    if m.castResumeOnClose then m.video.control = "pause"

    m.castModalName.text = valueOrEmpty(member.title)
    role = valueOrEmpty(member.description)
    if role <> "" then m.castModalRole.text = "as " + role else m.castModalRole.text = ""
    m.castModalMeta.text = ""
    m.castModalBio.text = ""
    m.castModalKnownFor.text = ""
    poster = valueOrEmpty(member.hdPosterUrl)
    if poster = "" then poster = "pkg:/images/poster_placeholder.png"
    m.castModalPhoto.uri = poster

    m.castModal.visible = true
    m.castModalSpinner.visible = true
    m.castModalSpinner.control = "start"

    m.personTask = createObject("roSGNode", "PlexTask")
    m.personTask.config = m.top.config
    m.personTask.action = "personDetail"
    m.personTask.item = member
    m.personTask.observeField("response", "onPersonDetail")
    m.personTask.control = "RUN"
end sub

sub onPersonDetail()
    m.castModalSpinner.control = "stop"
    m.castModalSpinner.visible = false

    ' A late reply must not repopulate a panel the viewer already dismissed
    if m.zone <> "castModal" then return

    response = m.personTask.response
    if response = invalid or response.ok <> true or response.person = invalid then
        m.castModalBio.text = "No biography available."
        return
    end if

    person = response.person
    if valueOrEmpty(person.title) <> "" then m.castModalName.text = valueOrEmpty(person.title)
    m.castModalMeta.text = valueOrEmpty(person.metaLine)
    m.castModalBio.text = valueOrEmpty(person.description)
    if m.castModalBio.text = "" then m.castModalBio.text = "No biography available."

    knownFor = valueOrEmpty(person.knownFor)
    if knownFor = "" then knownFor = creditSummary(response)
    if knownFor <> "" then m.castModalKnownFor.text = "Known for: " + knownFor

    photo = valueOrEmpty(person.hdPosterUrl)
    if photo <> "" then m.castModalPhoto.uri = photo
end sub

function creditSummary(response as Object) as String
    credits = response.credits
    if credits = invalid or credits.count() = 0 then return ""

    titles = []
    limit = 3
    if credits.count() < limit then limit = credits.count()
    for i = 0 to limit - 1
        title = valueOrEmpty(credits[i].title)
        if title <> "" then titles.push(title)
    end for
    return joinWith(titles, ", ")
end function

sub closeCastModal()
    m.castModal.visible = false
    m.castModalSpinner.control = "stop"
    m.castModalSpinner.visible = false
    if m.castResumeOnClose then m.video.control = "resume"
    m.castResumeOnClose = false
    showControls("cast")
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
    if m.activeMarker <> invalid then
        specs.push({ id: "skip", text: m.activeMarker.label })
    end if
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

    ' Markers appear and disappear mid-playback, so keep the highlight on the
    ' button the user was actually on rather than on whatever index it held
    focusedId = ""
    if m.buttonIndex < m.buttons.count() then focusedId = m.buttons[m.buttonIndex].id

    rebuildButtons(specs)

    m.buttonIndex = 0
    for i = 0 to m.buttons.count() - 1
        if m.buttons[i].id = focusedId then
            m.buttonIndex = i
            exit for
        end if
    end for
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
    ' The preview belongs to an in-flight seek, so it does not follow the viewer
    ' into a zone that cannot seek — least of all the cast strip it covers
    if zone <> "scrubber" and zone <> "buttons" then hidePreview()
    paintScrubber(m.position)
    paintButtons()
    paintButtonFocus()
    paintCastFocus()
    paintSkip()

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
    hidePreview()
    paintCastFocus()
    paintSkip()
    if not m.controls.visible then return
    m.fadingOut = true
    m.fadeInterp.keyValue = [m.controls.opacity, 0.0]
    m.fade.control = "start"
end sub

sub onFadeState()
    if m.fade.state = "stopped" and m.fadingOut then
        m.fadingOut = false
        m.controls.visible = false
        ' The pill waits for the panel to finish fading rather than crossing it
        paintSkip()
    end if
end sub

sub restartHideTimer()
    m.hideTimer.control = "stop"
    m.hideTimer.control = "start"
end sub

sub onHideTimer()
    if m.paused or m.zone = "picker" or m.zone = "castModal" then return
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
    showPreview(target)

    ' Let a run of presses settle before asking the transcoder for a new spot
    m.seekTimer.control = "stop"
    m.seekTimer.control = "start"
end sub

sub onSeekCommit()
    if m.pendingSeek = invalid then return
    target = m.pendingSeek
    m.pendingSeek = invalid
    hidePreview()
    m.video.seek = target
    m.position = target
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
        if m.zone = "castModal" then
            closeCastModal()
            return true
        end if
        if m.zone = "picker" then
            closePicker()
            return true
        end if
        stopAndClose()
        return true
    end if

    ' The modal owns everything while it is up, so playback is never disturbed
    ' by a stray press landing on the panel behind it
    if m.zone = "castModal" then
        ' Nothing in here is navigable, so the arrows are swallowed rather than
        ' leaking through to the scrubber behind
        if key = "OK" then closeCastModal()
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
        ' While a marker is live, OK belongs to the skip — that is the whole
        ' point of the pill being on screen without the panel
        if key = "OK" and m.activeMarker <> invalid then
            skipMarker()
            return true
        end if
        if key = "up" or key = "down" or key = "OK" or key = "left" or key = "right" then
            showControls("scrubber")
            return true
        end if
        return false
    end if

    if m.zone = "cast" then
        if key = "left" then
            moveCast(-1)
            return true
        else if key = "right" then
            moveCast(1)
            return true
        else if key = "down" then
            showControls("scrubber")
            return true
        else if key = "up" then
            hideControls()
            return true
        else if key = "OK" then
            openCastModal()
            return true
        end if
        return true
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
            if m.castNodes.count() > 0 then
                showControls("cast")
            else
                hideControls()
            end if
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
    else if id = "skip" then
        skipMarker()
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
