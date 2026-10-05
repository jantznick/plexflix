sub init()
    m.programTitle = m.top.findNode("programTitle")
    m.channelMeta = m.top.findNode("channelMeta")
    m.programSummary = m.top.findNode("programSummary")
    m.statusLabel = m.top.findNode("statusLabel")
    m.watchBg = m.top.findNode("watchBg")
    m.previewArt = m.top.findNode("previewArt")
    m.previewVideo = m.top.findNode("previewVideo")
    m.guideList = m.top.findNode("guideList")
    m.spinner = m.top.findNode("spinner")

    m.channels = []
    m.focusZone = "guide" ' guide | watch
    m.currentIndex = 0
    m.previewSession = ""

    m.guideList.observeField("itemFocused", "onGuideFocused")
    m.guideList.observeField("itemSelected", "onGuideSelected")

    m.tuneTimer = createObject("roSGNode", "Timer")
    m.tuneTimer.repeat = false
    m.tuneTimer.duration = 0.85
    m.tuneTimer.observeField("fire", "onTunePreview")
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadGuide()
end sub

sub loadGuide()
    m.statusLabel.text = "Loading guide..."
    m.top.loadingMessage = "Loading Live TV..."
    if m.spinner <> invalid then
        m.spinner.visible = true
        m.spinner.control = "start"
    end if

    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "liveTvGuide"
    m.task.observeField("response", "onGuideLoaded")
    m.task.control = "RUN"
end sub

sub onGuideLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if m.spinner <> invalid then
        m.spinner.control = "stop"
        m.spinner.visible = false
    end if

    if response = invalid or response.ok <> true then
        err = "Could not load Live TV guide"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        m.programTitle.text = "Live TV unavailable"
        return
    end if

    m.channels = response.channels
    if m.channels = invalid then m.channels = []

    root = createObject("roSGNode", "ContentNode")
    for each ch in m.channels
        child = root.createChild("ContentNode")
        child.title = formatGuideLine(ch)
    end for
    m.guideList.content = root

    if m.channels.count() = 0 then
        m.statusLabel.text = "No channels found"
        m.programTitle.text = "No channels"
        return
    end if

    m.statusLabel.text = ""
    m.guideList.jumpToItem = 0
    m.guideList.setFocus(true)
    m.focusZone = "guide"
    updateInfo(0)
    schedulePreviewTune()
end sub

function formatGuideLine(ch as Object) as String
    num = asString(ch.channelNumber)
    callSign = asString(ch.callSign)
    program = asString(ch.programTitle)
    if program = "" then program = "On now"
    left = ""
    if num <> "" and callSign <> "" then
        left = num + "  " + callSign
    else if callSign <> "" then
        left = callSign
    else if num <> "" then
        left = "Ch " + num
    else
        left = asString(ch.title)
    end if
    if Len(left) > 28 then left = Left(left, 28)
    ' pad-ish separator
    return left + "   ·   " + program
end function

sub onGuideFocused()
    idx = m.guideList.itemFocused
    if idx = invalid or idx < 0 or idx >= m.channels.count() then return
    m.currentIndex = idx
    updateInfo(idx)
    schedulePreviewTune()
end sub

sub updateInfo(idx as Integer)
    ch = m.channels[idx]
    if ch = invalid then return
    title = asString(ch.programTitle)
    if title = "" then title = asString(ch.title)
    m.programTitle.text = title

    metaBits = []
    if asString(ch.channelNumber) <> "" then metaBits.push(asString(ch.channelNumber))
    if asString(ch.callSign) <> "" then metaBits.push(asString(ch.callSign))
    if asString(ch.timeRange) <> "" then metaBits.push(asString(ch.timeRange))
    m.channelMeta.text = joinStrings(metaBits, "  ·  ")

    summary = asString(ch.description)
    if summary = "" then summary = asString(ch.title)
    m.programSummary.text = summary

    if asString(ch.hdPosterUrl) <> "" then
        m.previewArt.uri = ch.hdPosterUrl
        m.previewArt.visible = true
    end if
end sub

sub schedulePreviewTune()
    ' Debounce so scrolling the guide doesn't spam tuners
    m.tuneTimer.control = "stop"
    m.tuneTimer.control = "start"
end sub

sub onTunePreview()
    if m.channels.count() = 0 then return
    ch = m.channels[m.currentIndex]
    if ch = invalid then return
    m.statusLabel.text = "Tuning preview..."
    m.previewTask = createObject("roSGNode", "PlexTask")
    m.previewTask.config = m.top.config
    m.previewTask.action = "tuneLiveChannel"
    m.previewTask.item = ch
    m.previewTask.observeField("response", "onPreviewReady")
    m.previewTask.control = "RUN"
end sub

sub onPreviewReady()
    response = m.previewTask.response
    if response = invalid or response.ok <> true or response.url = invalid or response.url = "" then
        m.statusLabel.text = ""
        return
    end if
    m.statusLabel.text = ""
    m.previewSession = asString(response.sessionId)

    contentNode = createObject("roSGNode", "ContentNode")
    contentNode.url = response.url
    contentNode.streamFormat = "hls"
    contentNode.title = m.programTitle.text
    m.previewVideo.content = contentNode
    m.previewVideo.visible = true
    m.previewArt.visible = false
    m.previewVideo.control = "play"
end sub

sub onGuideSelected()
    requestWatch()
end sub

sub requestWatch()
    if m.channels.count() = 0 then return
    ch = m.channels[m.currentIndex]
    if ch = invalid then return
    ' Fullscreen playback via parent
    m.top.selectedItem = {
        title: asString(ch.programTitle),
        description: asString(ch.description),
        mediaType: "livetv",
        ratingKey: asString(ch.ratingKey),
        key: asString(ch.key),
        channelId: asString(ch.channelId),
        dvrId: asString(ch.dvrId),
        hdPosterUrl: asString(ch.hdPosterUrl),
        hdBackdropUrl: asString(ch.hdBackdropUrl),
        duration: 0,
        viewOffset: 0
    }
end sub

sub paintWatchFocus()
    if m.focusZone = "watch" then
        m.watchBg.color = "0xFF2A2A"
    else
        m.watchBg.color = "0xE50914"
    end if
end sub

sub onRefocus()
    if m.top.refocus = true then
        m.focusZone = "guide"
        paintWatchFocus()
        m.guideList.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left"
        if m.focusZone = "guide" then
            m.top.openMenu = true
            return true
        end if
    else if key = "up"
        if m.focusZone = "guide" then
            m.focusZone = "watch"
            paintWatchFocus()
            m.top.setFocus(true)
            return true
        end if
    else if key = "down"
        if m.focusZone = "watch" then
            m.focusZone = "guide"
            paintWatchFocus()
            m.guideList.setFocus(true)
            return true
        end if
    else if key = "OK" or key = "play"
        if m.focusZone = "watch" or m.guideList.hasFocus() then
            requestWatch()
            return true
        end if
    else if key = "back"
        stopPreview()
        return false
    end if
    return false
end function

sub stopPreview()
    if m.previewVideo <> invalid then m.previewVideo.control = "stop"
end sub

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    return ""
end function
