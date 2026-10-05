sub init()
    m.eventTitle = m.top.findNode("eventTitle")
    m.eventMeta = m.top.findNode("eventMeta")
    m.eventSummary = m.top.findNode("eventSummary")
    m.statusLabel = m.top.findNode("statusLabel")
    m.clockLabel = m.top.findNode("clockLabel")
    m.watchBg = m.top.findNode("watchBg")
    m.previewArt = m.top.findNode("previewArt")
    m.guideList = m.top.findNode("guideList")

    m.events = []
    m.focusZone = "guide"
    m.currentIndex = 0

    m.guideList.observeField("itemFocused", "onGuideFocused")
    m.guideList.observeField("itemSelected", "onGuideSelected")

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
    for i = 1 to 9
        child = root.createChild("ContentNode")
        child.title = padRight("—", 28) + padRight("Loading sports…", 52) + padRight("—", 28) + "—"
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
            child.title = formatLine(item, league)
        end for
    end for

    m.guideList.content = root
    if m.events.count() = 0 then
        m.statusLabel.text = "No live sports — check sportsFeedUrl"
        m.eventTitle.text = "No events"
    else
        m.statusLabel.text = StrI(m.events.count()).Trim() + " events"
        m.guideList.jumpToItem = 0
        m.guideList.setFocus(true)
        updateInfo(0)
    end if
end sub

function formatLine(item as Object, league as String) as String
    lg = league
    if Len(lg) > 22 then lg = Mid(lg, 1, 22)
    title = asString(item.title)
    if Len(title) > 46 then title = Mid(title, 1, 46)
    info = asString(item.description)
    if Len(info) > 24 then info = Mid(info, 1, 24)
    if info = "" then info = "—"
    return padRight(lg, 28) + padRight(title, 52) + padRight(info, 28) + "LIVE"
end function

function padRight(text as String, width as Integer) as String
    if Len(text) >= width then return Mid(text, 1, width)
    out = text
    while Len(out) < width
        out = out + " "
    end while
    return out
end function

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
    if meta = "" then meta = "Live sports"
    m.eventMeta.text = meta
    m.eventSummary.text = asString(item.description)
    if asString(item.hdPosterUrl) <> "" then
        m.previewArt.uri = item.hdPosterUrl
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

sub paintWatchFocus()
    if m.focusZone = "watch" then
        m.watchBg.color = "0xFFFFFF"
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

sub onEscapeLeft()
    m.top.openMenu = true
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
        requestOpen()
        return true
    end if
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
