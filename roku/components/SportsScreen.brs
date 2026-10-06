sub init()
    m.eventTitle = m.top.findNode("eventTitle")
    m.eventMeta = m.top.findNode("eventMeta")
    m.eventSummary = m.top.findNode("eventSummary")
    m.statusLabel = m.top.findNode("statusLabel")
    m.clockLabel = m.top.findNode("clockLabel")
    m.previewArt = m.top.findNode("previewArt")
    m.guideList = m.top.findNode("guideList")

    m.pillRow = m.top.findNode("pillRow")
    m.pills = []
    m.categories = []
    m.pillIndex = 0
    m.zone = "list"

    m.previewH = 196
    m.previewW = Int(m.previewH * 16 / 9)
    m.previewX = 1020

    if m.previewArt <> invalid then
        m.previewArt.loadDisplayMode = "scaleToZoom"
        m.previewArt.loadWidth = 1280
        m.previewArt.loadHeight = 720
        m.previewArt.width = m.previewW
        m.previewArt.height = m.previewH
        m.previewArt.translation = [m.previewX, 0]
    end if
    previewBg = m.top.findNode("previewBg")
    if previewBg <> invalid then
        previewBg.width = m.previewW
        previewBg.height = m.previewH
        previewBg.translation = [m.previewX, 0]
    end if

    m.events = []
    m.currentIndex = 0

    ' Games picked for multiview, kept across sport filters and the game page
    m.multi = []
    m.multiEnabled = false
    m.multiTray = m.top.findNode("multiTray")
    m.multiCount = m.top.findNode("multiCount")
    m.multiList = m.top.findNode("multiList")
    m.multiHint = m.top.findNode("multiHint")

    m.guideList.observeField("itemFocused", "onGuideFocused")
    m.guideList.observeField("itemSelected", "onGuideSelected")
    m.guideList.observeField("escapeUp", "onGuideEscapeUp")
    m.guideList.observeField("escapeLeft", "onGuideEscapeLeft")
    m.guideList.observeField("escapeBack", "onGuideEscapeBack")

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
    url = m.top.config.multiviewUrl
    m.multiEnabled = (url <> invalid and url <> "")
    paintMultiTray()
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

    allItems = []
    m.categories = []
    for each rowData in rows
        league = asString(rowData.title)
        if league = "" then league = "Live"
        items = rowData.items
        if items = invalid then items = []
        if items.count() > 0 then
            for each item in items
                item.league = league
                allItems.push(item)
            end for
            m.categories.push({ title: prettyCategory(league), items: items })
        end if
    end for
    ' "All" leads so the unfiltered guide is one press away from any sport
    m.categories.unshift({ title: "All", items: allItems })

    ' A reload keeps the sport you were looking at when it still exists
    keep = 0
    if m.pills.count() > 0 and m.pillIndex < m.pills.count() then
        current = m.pills[m.pillIndex].title
        for i = 0 to m.categories.count() - 1
            if m.categories[i].title = current then keep = i
        end for
    end if

    buildPills()
    applyCategory(keep)
    if m.zone = "list" then m.guideList.setFocus(true)
end sub

' Feed keys are shouty slugs ("AMERICAN-FOOTBALL"); "24/7 Channels" is already fine
function prettyCategory(raw as String) as String
    if raw <> UCase(raw) then return raw
    words = raw.Replace("-", " ").Replace("_", " ").Split(" ")
    out = ""
    for each word in words
        if word <> "" then
            if out <> "" then out = out + " "
            out = out + UCase(Left(word, 1)) + LCase(Mid(word, 2))
        end if
    end for
    return out
end function

sub applyCategory(index as Integer)
    if index < 0 or index >= m.categories.count() then index = 0
    m.pillIndex = index
    paintPills()

    m.events = []
    root = createObject("roSGNode", "ContentNode")
    if m.categories.count() > 0 then
        for each item in m.categories[index].items
            m.events.push(item)
            child = root.createChild("ContentNode")
            applySportsLine(child, item, asString(item.league))
        end for
    end if

    m.guideList.content = root
    m.currentIndex = 0
    if m.events.count() = 0 then
        m.statusLabel.text = "No live sports — check sportsFeedUrl"
        m.eventTitle.text = "No events"
        m.eventMeta.text = ""
        m.eventSummary.text = ""
    else
        m.statusLabel.text = StrI(m.events.count()).Trim() + " events"
        m.guideList.jumpToItem = 0
        updateInfo(0)
    end if
end sub

'--------------------------------------------------------------------
' Pills
'--------------------------------------------------------------------

sub buildPills()
    while m.pillRow.getChildCount() > 0
        m.pillRow.removeChildIndex(0)
    end while
    m.pills = []

    x = 0
    for each category in m.categories
        group = m.pillRow.createChild("Group")
        group.translation = [x, 2]

        bg = group.createChild("Rectangle")
        bg.height = 52

        label = group.createChild("Label")
        label.height = 52
        label.vertAlign = "center"
        label.horizAlign = "center"
        label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 28)
        label.text = category.title + "  " + StrI(category.items.count()).Trim()

        textW = label.boundingRect().width
        if textW <= 0 then textW = Len(label.text) * 15
        width = Int(textW) + 56
        bg.width = width
        label.width = width

        m.pills.push({ title: category.title, group: group, bg: bg, label: label, x: x, width: width })
        x = x + width + 14
    end for
    m.pillRow.translation = [0, 0]
end sub

sub paintPills()
    for i = 0 to m.pills.count() - 1
        pill = m.pills[i]
        selected = (i = m.pillIndex)
        if selected and m.zone = "pills" then
            pill.bg.color = "0xFFFFFF"
            pill.label.color = "0x0A0E18"
        else if selected then
            pill.bg.color = "0xE50914"
            pill.label.color = "0xFFFFFF"
        else
            pill.bg.color = "0x1E2638"
            pill.label.color = "0xC5CCD8"
        end if
    end for
    scrollPillsIntoView()
end sub

sub scrollPillsIntoView()
    if m.pills.count() = 0 then return
    viewW = 1728
    pill = m.pills[m.pillIndex]
    offset = -m.pillRow.translation[0]
    if pill.x < offset then offset = pill.x
    if pill.x + pill.width > offset + viewW then offset = pill.x + pill.width - viewW
    if offset < 0 then offset = 0
    m.pillRow.translation = [-offset, 0]
end sub

sub focusPills()
    if m.pills.count() < 2 then return
    m.zone = "pills"
    m.top.setFocus(true)
    paintPills()
end sub

sub focusList()
    m.zone = "list"
    paintPills()
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
    if eventInMultiview(item) then streamsCol = streamsCol + "  ·  Multiview"
    setGuideCols(node, lg, title, "", streamsCol)
end sub

'--------------------------------------------------------------------
' Multiview picks
'--------------------------------------------------------------------

function multiviewMax() as Integer
    return 4
end function

' A pick is one stream, so the game page can add a specific alternate; from
' the guide it is the event's first stream
function eventStreamUrl(item as Object) as String
    if item = invalid then return ""
    url = asString(item.streamUrl)
    if url = "" and item.streams <> invalid and item.streams.count() > 0 then url = asString(item.streams[0].streamUrl)
    return url
end function

function multiIndexOf(url as String) as Integer
    for i = 0 to m.multi.count() - 1
        if m.multi[i].url = url then return i
    end for
    return -1
end function

function eventInMultiview(item as Object) as Boolean
    if m.multi.count() = 0 or item = invalid then return false
    if multiIndexOf(eventStreamUrl(item)) >= 0 then return true
    if item.streams <> invalid then
        for each stream in item.streams
            if multiIndexOf(asString(stream.streamUrl)) >= 0 then return true
        end for
    end if
    return false
end function

' Returns what happened, for whichever screen the viewer is looking at
function toggleMultiview(pick as Object) as String
    url = asString(pick.url)
    if url = "" then return ""
    title = asString(pick.title)
    index = multiIndexOf(url)
    if index >= 0 then
        m.multi.delete(index)
        message = "Removed " + title + " from multiview"
    else if m.multi.count() >= multiviewMax() then
        return "Multiview holds " + StrI(multiviewMax()).Trim() + " games. Remove one first."
    else
        m.multi.push(pick)
        message = "Added " + title + " to multiview (" + StrI(m.multi.count()).Trim() + " of " + StrI(multiviewMax()).Trim() + ")"
    end if
    paintMultiTray()
    refreshMultiviewRows()
    return message
end function

sub toggleFocusedEvent()
    if m.currentIndex >= m.events.count() then return
    item = m.events[m.currentIndex]
    message = toggleMultiview({
        url: eventStreamUrl(item),
        title: asString(item.title),
        league: asString(item.league),
        streamFormat: asString(item.streamFormat),
        hdPosterUrl: asString(item.hdPosterUrl)
    })
    if message <> "" then m.statusLabel.text = message
end sub

' Rows are swapped rather than edited: a list item only redraws when it is
' handed a new content node
sub refreshMultiviewRows()
    root = m.guideList.content
    if root = invalid then return
    for i = 0 to m.events.count() - 1
        if i < root.getChildCount() then
            old = root.getChild(i)
            fresh = createObject("roSGNode", "ContentNode")
            applySportsLine(fresh, m.events[i], asString(m.events[i].league))
            if fresh.col3 <> old.col3 then root.replaceChild(fresh, i)
        end if
    end for
end sub

sub paintMultiTray()
    if m.multiTray = invalid then return
    m.multiTray.visible = m.multiEnabled
    if not m.multiEnabled then return

    m.multiCount.text = "MULTIVIEW  " + StrI(m.multi.count()).Trim() + "/" + StrI(multiviewMax()).Trim()
    names = ""
    for each pick in m.multi
        ' One line each, so four picks always fit the four lines
        line = pick.title
        if Len(line) > 26 then line = Left(line, 25) + "…"
        if names <> "" then names = names + Chr(10)
        names = names + line
    end for
    m.multiList.text = names
    if m.multi.count() = 0 then
        m.multiHint.text = "Press * on a game to add it"
    else if m.multi.count() = 1 then
        m.multiHint.text = "Add one more game with *"
    else
        m.multiHint.text = "Press Play to watch together"
    end if
end sub

' Called from here or, through MainScene, from the game page
function requestMultiview() as String
    if not m.multiEnabled then return ""
    if m.multi.count() < 2 then return "Pick at least 2 games with * first"
    m.top.multiviewRequested = { streams: m.multi, layout: "grid" }
    return ""
end function

sub onMultiviewToggle()
    pick = m.top.multiviewToggle
    if pick = invalid then return
    m.top.multiviewMessage = toggleMultiview(pick)
end sub

sub onLaunchMultiview()
    if m.top.launchMultiview <> true then return
    m.top.multiviewMessage = requestMultiview()
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
    uri = asString(item.hdPosterUrl)
    if uri = "" then uri = asString(item.hdBackdropUrl)
    if uri <> "" and m.previewArt <> invalid then
        m.previewArt.loadDisplayMode = "scaleToZoom"
        m.previewArt.loadWidth = 1280
        m.previewArt.loadHeight = 720
        m.previewArt.width = m.previewW
        m.previewArt.height = m.previewH
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
    focusPills()
end sub

sub onGuideEscapeLeft()
    m.top.openMenu = true
end sub

sub onGuideEscapeBack()
    m.top.openMenu = true
end sub

sub onRefocus()
    if m.top.refocus = true then
        if m.zone = "pills" then
            m.top.setFocus(true)
        else
            m.guideList.setFocus(true)
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.multiEnabled and m.zone = "list" then
        if key = "options" then
            toggleFocusedEvent()
            return true
        else if key = "play" then
            message = requestMultiview()
            if message <> "" then m.statusLabel.text = message
            return true
        end if
    end if
    if m.zone <> "pills" then return false

    ' Moving between sports filters at once, the way streaming apps' genre
    ' tabs do; there is nothing to confirm
    if key = "left" then
        if m.pillIndex = 0 then
            m.top.openMenu = true
        else
            applyCategory(m.pillIndex - 1)
        end if
        return true
    else if key = "right" then
        if m.pillIndex < m.pills.count() - 1 then applyCategory(m.pillIndex + 1)
        return true
    else if key = "down" or key = "OK" or key = "back" then
        if m.events.count() = 0 then return key <> "back"
        focusList()
        return true
    else if key = "up" then
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
