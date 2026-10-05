sub init()
    m.eventTitle = m.top.findNode("eventTitle")
    m.eventMeta = m.top.findNode("eventMeta")
    m.eventSummary = m.top.findNode("eventSummary")
    m.statusLabel = m.top.findNode("statusLabel")
    m.clockLabel = m.top.findNode("clockLabel")
    m.previewArt = m.top.findNode("previewArt")
    m.guideList = m.top.findNode("guideList")

    if m.previewArt <> invalid then
        m.previewArt.loadDisplayMode = "scaleToZoom"
        m.previewArt.loadWidth = 1400
        m.previewArt.loadHeight = 500
        m.previewArt.width = 700
        m.previewArt.height = 250
    end if

    m.events = []
    m.currentIndex = 0

    m.guideList.observeField("itemFocused", "onGuideFocused")
    m.guideList.observeField("itemSelected", "onGuideSelected")
    m.guideList.observeField("escapeUp", "onGuideEscapeUp")
    m.guideList.observeField("escapeLeft", "onGuideEscapeLeft")

    m.clockTimer = createObject("roSGNode", "Timer")
    m.clockTimer.repeat = true
    m.clockTimer.duration = 30
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    updateClock()
    showSkeleton()
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

sub showSkeleton()
    root = createObject("roSGNode", "ContentNode")
    for i = 1 to 12
        child = root.createChild("ContentNode")
        setGuideCols(child, "—", "Loading sports…", "", "—")
    end for
    m.guideList.content = root
    m.guideList.setFocus(true)
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadFeed()
end sub

sub loadFeed()
    m.statusLabel.text = "Loading…"
    m.top.loadingMessage = "Loading sports feed…"
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "sportsFeed"
    m.task.observeField("response", "onFeedLoaded")
    m.task.control = "RUN"
end sub

sub onFeedLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if response = invalid or response.ok <> true then
        err = "Could not load sports feed"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        m.eventTitle.text = "Sports unavailable"
        return
    end if

    rows = response.rows
    if rows = invalid then rows = []

    m.events = []
    root = createObject("roSGNode", "ContentNode")
    for each rowData in rows
        league = asString(rowData.title)
        if league = "" then league = "Live"
        items = rowData.items
        if items = invalid then items = []
        for each item in items
            item.league = league
            m.events.push(item)
            child = root.createChild("ContentNode")
            applySportsLine(child, item, league)
        end for
    end for

    m.guideList.content = root
    if m.events.count() = 0 then
        m.statusLabel.text = "No live sports — check sportsFeedUrl"
        m.eventTitle.text = "No events"
    else
        m.statusLabel.text = StrI(m.events.count()).Trim() + " events · OK to open"
        m.guideList.jumpToItem = 0
        m.guideList.setFocus(true)
        updateInfo(0)
    end if
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

sub applySportsLine(node as Object, item as Object, league as String)
    lg = league
    if Len(lg) > 26 then lg = Mid(lg, 1, 26)
    title = asString(item.title)
    if Len(title) > 52 then title = Mid(title, 1, 52)
    n = 0
    if item.DoesExist("streamCount") then n = item.streamCount
    if n = 0 and item.DoesExist("streams") and item.streams <> invalid then n = item.streams.count()
    if n = 0 and asString(item.streamUrl) <> "" then n = 1
    streamsCol = StrI(n).Trim() + " streams"
    if n = 1 then streamsCol = "1 stream"
    setGuideCols(node, lg, title, "", streamsCol)
end sub

sub onGuideFocused()
    idx = m.guideList.itemFocused
    if idx = invalid or idx < 0 or idx >= m.events.count() then return
    m.currentIndex = idx
    updateInfo(idx)
end sub

sub updateInfo(idx as Integer)
    item = m.events[idx]
    if item = invalid then return
    m.eventTitle.text = asString(item.title)
    meta = asString(item.league)
    if meta = "" then meta = asString(item.description)
    if meta = "" then meta = "Live sports"
    m.eventMeta.text = meta
    n = 0
    if item.DoesExist("streamCount") then n = item.streamCount
    if n = 0 and item.DoesExist("streams") and item.streams <> invalid then n = item.streams.count()
    if n = 0 and asString(item.streamUrl) <> "" then n = 1
    if n = 1 then
        m.eventSummary.text = "1 stream available"
    else if n > 1 then
        m.eventSummary.text = StrI(n).Trim() + " streams available"
    else
        m.eventSummary.text = ""
    end if
    uri = asString(item.hdBackdropUrl)
    if uri = "" then uri = asString(item.hdPosterUrl)
    if uri <> "" and m.previewArt <> invalid then
        m.previewArt.loadDisplayMode = "scaleToZoom"
        m.previewArt.loadWidth = 1280
        m.previewArt.loadHeight = 720
        m.previewArt.width = 480
        m.previewArt.height = 270
        m.previewArt.uri = uri
        m.previewArt.opacity = 1.0
    end if
end sub

sub onGuideSelected()
    requestOpen()
end sub

sub requestOpen()
    if m.events.count() = 0 then return
    item = m.events[m.currentIndex]
    if item = invalid then return
    m.top.selectedItem = item
end sub

sub onGuideEscapeUp()
end sub

sub onGuideEscapeLeft()
    m.top.openMenu = true
end sub

sub onRefocus()
    if m.top.refocus = true then
        m.guideList.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    return false
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
