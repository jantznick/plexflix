sub init()
    m.programTitle = m.top.findNode("programTitle")
    m.channelMeta = m.top.findNode("channelMeta")
    m.programSummary = m.top.findNode("programSummary")
    m.statusLabel = m.top.findNode("statusLabel")
    m.clockLabel = m.top.findNode("clockLabel")
    m.watchBg = m.top.findNode("watchBg")
    m.watchLabel = m.top.findNode("watchLabel")
    m.previewArt = m.top.findNode("previewArt")
    m.previewVideo = m.top.findNode("previewVideo")
    m.previewHint = m.top.findNode("previewHint")
    m.guideList = m.top.findNode("guideList")

    m.channels = []
    m.focusZone = "guide"
    m.currentIndex = 0
    m.guideLoaded = false

    m.guideList.observeField("itemFocused", "onGuideFocused")
    m.guideList.observeField("itemSelected", "onGuideSelected")

    m.tuneTimer = createObject("roSGNode", "Timer")
    m.tuneTimer.repeat = false
    m.tuneTimer.duration = 0.85
    m.tuneTimer.observeField("fire", "onTunePreview")

    m.clockTimer = createObject("roSGNode", "Timer")
    m.clockTimer.repeat = true
    m.clockTimer.duration = 30
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    updateClock()

    showGuideSkeleton()
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    h = dt.GetHours()
    mi = dt.GetMinutes()
    ampm = "AM"
    if h >= 12 then ampm = "PM"
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    minStr = StrI(mi).Trim()
    if Len(minStr) = 1 then minStr = "0" + minStr
    m.clockLabel.text = StrI(h12).Trim() + ":" + minStr + " " + ampm
end sub

sub showGuideSkeleton()
    root = createObject("roSGNode", "ContentNode")
    for i = 1 to 12
        child = root.createChild("ContentNode")
        setGuideCols(child, "—", "Loading…", "—", "")
    end for
    m.guideList.content = root
    m.guideList.setFocus(true)
    m.focusZone = "guide"
    paintWatchFocus()
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadGuide()
end sub

sub loadGuide()
    m.statusLabel.text = "Loading guide…"
    m.top.loadingMessage = "Loading Live TV…"
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "liveTvGuide"
    m.task.observeField("response", "onGuideLoaded")
    m.task.control = "RUN"
end sub

sub onGuideLoaded()
    response = m.task.response
    m.top.loadingMessage = ""

    if response = invalid or response.ok <> true then
        err = "Could not load channels"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        m.programTitle.text = "Guide unavailable"
        m.programSummary.text = err
        showEmptyGuide(err)
        return
    end if

    m.channels = response.channels
    if m.channels = invalid then m.channels = []

    if m.channels.count() = 0 then
        m.statusLabel.text = "No channels"
        showEmptyGuide("No channels configured")
        return
    end if

    root = createObject("roSGNode", "ContentNode")
    for each ch in m.channels
        child = root.createChild("ContentNode")
        applyGuideLine(child, ch)
    end for
    m.guideList.content = root
    m.guideLoaded = true
    m.statusLabel.text = StrI(m.channels.count()).Trim() + " channels"
    m.guideList.jumpToItem = 0
    m.guideList.setFocus(true)
    m.focusZone = "guide"
    updateInfo(0)
    schedulePreviewTune()
end sub

sub showEmptyGuide(hint as String)
    root = createObject("roSGNode", "ContentNode")
    for i = 1 to 12
        child = root.createChild("ContentNode")
        if i = 1 then
            setGuideCols(child, "—", hint, "—", "")
        else
            setGuideCols(child, "—", "—", "—", "")
        end if
    end for
    m.guideList.content = root
    m.channels = []
    m.guideLoaded = false
    m.guideList.setFocus(true)
end sub

sub setGuideCols(node as Object, c0 as String, c1 as String, c2 as String, c3 as String)
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

sub applyGuideLine(node as Object, ch as Object)
    num = asString(ch.channelNumber)
    callSign = asString(ch.callSign)
    if Len(callSign) > 22 then callSign = Mid(callSign, 1, 22)
    program = asString(ch.programTitle)
    if program = "" then program = asString(ch.title)
    if program = "" then program = "On now"
    if Len(program) > 42 then program = Mid(program, 1, 42)

    nextShow = asString(ch.nextTitle)
    if nextShow = "" then nextShow = "—"
    if Len(nextShow) > 36 then nextShow = Mid(nextShow, 1, 36)

    channelCol = ""
    if num <> "" and callSign <> "" then
        channelCol = num + "  " + callSign
    else if callSign <> "" then
        channelCol = callSign
    else if num <> "" then
        channelCol = "Ch " + num
    else
        channelCol = Mid(asString(ch.title), 1, 24)
    end if
    if Len(channelCol) > 28 then channelCol = Mid(channelCol, 1, 28)
    if LCase(channelCol) = LCase(program) then channelCol = "Ch"

    statusCol = asString(ch.timeRange)
    if statusCol = "" then statusCol = "LIVE"
    setGuideCols(node, channelCol, program, nextShow, statusCol)
end sub

sub onGuideFocused()
    idx = m.guideList.itemFocused
    if idx = invalid or idx < 0 then return
    if not m.guideLoaded or idx >= m.channels.count() then return
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
    if summary = "" then summary = "Live on " + asString(ch.callSign)
    if asString(ch.nextTitle) <> "" then
        summary = summary + "  ·  Up next: " + asString(ch.nextTitle)
    end if
    m.programSummary.text = summary

    if asString(ch.hdPosterUrl) <> "" then
        m.previewArt.uri = ch.hdPosterUrl
        m.previewArt.opacity = 1.0
        if m.previewHint <> invalid then m.previewHint.visible = false
    end if
end sub

sub schedulePreviewTune()
    if not m.guideLoaded then return
    m.tuneTimer.control = "stop"
    m.tuneTimer.control = "start"
end sub

sub onTunePreview()
    if m.channels.count() = 0 then return
    ch = m.channels[m.currentIndex]
    if ch = invalid then return
    m.statusLabel.text = "Tuning preview…"
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
        m.statusLabel.text = StrI(m.channels.count()).Trim() + " channels"
        return
    end if
    m.statusLabel.text = StrI(m.channels.count()).Trim() + " channels"
    contentNode = createObject("roSGNode", "ContentNode")
    contentNode.url = response.url
    contentNode.streamFormat = "hls"
    contentNode.title = m.programTitle.text
    m.previewVideo.content = contentNode
    m.previewVideo.visible = true
    m.previewArt.visible = false
    if m.previewHint <> invalid then m.previewHint.visible = false
    m.previewVideo.control = "play"
end sub

sub onGuideSelected()
    requestWatch()
end sub

sub requestWatch()
    if m.channels.count() = 0 then return
    ch = m.channels[m.currentIndex]
    if ch = invalid then return
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
        m.watchBg.color = "0xFFFFFF"
        if m.watchLabel <> invalid then m.watchLabel.color = "0x111118"
    else
        m.watchBg.color = "0xE50914"
        if m.watchLabel <> invalid then m.watchLabel.color = "0xFFFFFF"
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
        if m.previewVideo <> invalid then m.previewVideo.control = "stop"
        return false
    end if
    return false
end function

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
