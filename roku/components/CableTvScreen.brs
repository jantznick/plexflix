sub init()
    m.programTitle = m.top.findNode("programTitle")
    m.programSub = m.top.findNode("programSub")
    m.programMeta = m.top.findNode("programMeta")
    m.programSummary = m.top.findNode("programSummary")
    m.badgeRow = m.top.findNode("badgeRow")
    m.heroArt = m.top.findNode("heroArt")
    m.tabRow = m.top.findNode("tabRow")
    m.previewArt = m.top.findNode("previewArt")
    m.previewHint = m.top.findNode("previewHint")
    m.clockLabel = m.top.findNode("clockLabel")
    m.slotHeader = m.top.findNode("slotHeader")
    m.gridRows = m.top.findNode("gridRows")
    m.pastShade = m.top.findNode("pastShade")
    m.nowLine = m.top.findNode("nowLine")
    m.guideStatus = m.top.findNode("guideStatus")

    ' Matches CableTvScreen.xml / LiveTvScreen geometry
    m.gridTop = 436
    m.rowH = 80
    m.rowGap = 6
    m.visibleRows = 7
    m.chanX = 96
    m.chanW = 256
    m.progX = 360
    m.progW = 1512
    m.winLen = 7200
    m.slotLen = 1800
    m.pxPerSec = m.progW / m.winLen

    m.allChannels = []
    m.channels = []
    m.categories = []
    m.focusCh = 0
    m.focusProg = 0
    m.topRow = 0
    m.anchor = 0
    m.minWin = floorSlot(nowSeconds())
    m.winStart = m.minWin
    m.loadedEnd = m.minWin + m.winLen
    m.rows = []
    m.slotLabels = []
    m.slotTicks = []
    m.tabNames = ["All"]
    m.tab = 0
    m.zone = "grid"
    m.guideLoaded = false

    buildTabs()
    buildSlotHeader()
    buildRows()

    m.clockTimer = createObject("roSGNode", "Timer")
    m.clockTimer.repeat = true
    m.clockTimer.duration = 15
    m.clockTimer.observeField("fire", "onClockTick")
    m.clockTimer.control = "start"

    m.previewHint.text = "PREVIEW"
    updateClock()
    paintTabs()
    renderGrid()
    showGuideStatus("Loading cable guide…")
    m.top.setFocus(true)
end sub

' ---------------------------------------------------------------------------
' Time helpers
' ---------------------------------------------------------------------------

function nowSeconds() as Integer
    return CreateObject("roDateTime").AsSeconds()
end function

function floorSlot(t as Integer) as Integer
    return t - (t mod 1800)
end function

function localTime(t as Integer) as Object
    dt = CreateObject("roDateTime")
    dt.FromSeconds(t)
    dt.ToLocalTime()
    return dt
end function

function clockText(t as Integer, withMeridiem as Boolean) as String
    if t <= 0 then return ""
    dt = localTime(t)
    h = dt.GetHours()
    mi = dt.GetMinutes()
    ampm = " AM"
    if h >= 12 then ampm = " PM"
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    minStr = StrI(mi).Trim()
    if Len(minStr) = 1 then minStr = "0" + minStr
    out = StrI(h12).Trim() + ":" + minStr
    if withMeridiem then out = out + ampm
    return out
end function

function dayKey(t as Integer) as String
    dt = localTime(t)
    return StrI(dt.GetYear()).Trim() + "-" + StrI(dt.GetMonth()).Trim() + "-" + StrI(dt.GetDayOfMonth()).Trim()
end function

function dayLabel(t as Integer) as String
    nowT = nowSeconds()
    if dayKey(t) = dayKey(nowT) then return "Today"
    if dayKey(t) = dayKey(nowT + 86400) then return "Tomorrow"
    return Left(localTime(t).GetWeekday(), 3)
end function

function rangeText(b as Integer, e as Integer) as String
    if b <= 0 then return ""
    startMer = clockText(b, true)
    if e <= b then return startMer
    endMer = clockText(e, true)
    if Right(startMer, 2) = Right(endMer, 2) then return clockText(b, false) + " – " + endMer
    return startMer + " – " + endMer
end function

function isOnNow(p as Object) as Boolean
    if p = invalid then return false
    t = nowSeconds()
    return p.lb <= t and p.endsAt > t
end function

sub updateClock()
    m.clockLabel.text = clockText(nowSeconds(), true)
end sub

sub onClockTick()
    updateClock()
    newMin = floorSlot(nowSeconds())
    if newMin > m.minWin then
        m.minWin = newMin
        if m.winStart < m.minWin then
            m.winStart = m.minWin
            if m.guideLoaded then refocusAnchor(m.winStart)
        end if
        rebuildPrograms()
        renderGrid()
    else
        paintNowLine()
    end if
    if m.zone = "grid" then updateGridInfo()
end sub

' ---------------------------------------------------------------------------
' Static chrome
' ---------------------------------------------------------------------------

sub buildTabs()
    m.tabNodes = []
    x = 240
    for i = 0 to m.tabNames.count() - 1
        addTabNode(m.tabNames[i], x)
        x = x + 40 + Len(m.tabNames[i]) * 17 + 12
    end for
end sub

sub addTabNode(title as String, x as Integer)
    w = 40 + Len(title) * 17
    g = m.tabRow.createChild("Group")
    g.translation = [x, 0]
    bg = g.createChild("Rectangle")
    bg.width = w
    bg.height = 48
    lbl = g.createChild("Label")
    lbl.width = w
    lbl.height = 48
    lbl.horizAlign = "center"
    lbl.vertAlign = "center"
    lbl.text = title
    lbl.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 28)
    m.tabNodes.push({ bg: bg, label: lbl, width: w, group: g })
end sub

sub rebuildTabChrome()
    ' Drop dynamic tabs (keep the CABLE TV title label at index 0)
    while m.tabRow.getChildCount() > 1
        m.tabRow.removeChildIndex(1)
    end while
    m.tabNodes = []
    x = 240
    for i = 0 to m.tabNames.count() - 1
        addTabNode(m.tabNames[i], x)
        x = x + 40 + Len(m.tabNames[i]) * 17 + 12
    end for
    paintTabs()
end sub

sub paintTabs()
    for i = 0 to m.tabNodes.count() - 1
        node = m.tabNodes[i]
        if i = m.tab and m.zone = "tabs" then
            node.bg.color = "0xEDF0F5"
            node.bg.opacity = 1.0
            node.label.color = "0x0A0E18"
        else if i = m.tab then
            node.bg.color = "0x2A3348"
            node.bg.opacity = 1.0
            node.label.color = "0xFFFFFF"
        else
            node.bg.opacity = 0.0
            node.label.color = "0x8FA0B8"
        end if
    end for
end sub

sub buildSlotHeader()
    for k = 0 to 3
        tick = m.slotHeader.createChild("Rectangle")
        tick.width = 2
        tick.height = 44
        tick.color = "0x2A3348"
        tick.translation = [m.progX + Int(k * m.slotLen * m.pxPerSec), 392]
        m.slotTicks.push(tick)
        lbl = m.slotHeader.createChild("Label")
        lbl.width = Int(m.slotLen * m.pxPerSec) - 24
        lbl.height = 44
        lbl.vertAlign = "center"
        lbl.color = "0xA8B0C0"
        lbl.translation = [m.progX + Int(k * m.slotLen * m.pxPerSec) + 14, 392]
        lbl.font = MakeFont("pkg:/fonts/Outfit-Medium.ttf", 26)
        m.slotLabels.push(lbl)
    end for
end sub

sub buildRows()
    for r = 0 to m.visibleRows - 1
        g = m.gridRows.createChild("Group")
        g.translation = [0, m.gridTop + 8 + r * (m.rowH + m.rowGap)]
        chanBg = g.createChild("Rectangle")
        chanBg.translation = [m.chanX, 0]
        chanBg.width = m.chanW
        chanBg.height = m.rowH
        chanBar = g.createChild("Rectangle")
        chanBar.translation = [m.chanX, 0]
        chanBar.width = 5
        chanBar.height = m.rowH
        chanBar.color = "0xE50914"
        logo = g.createChild("Poster")
        logo.translation = [m.chanX + 14, 12]
        logo.width = 96
        logo.height = 56
        logo.loadDisplayMode = "scaleToFit"
        logo.loadWidth = 160
        logo.loadHeight = 90
        num = g.createChild("Label")
        num.height = 38
        num.vertAlign = "center"
        num.wrap = false
        num.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 30)
        sign = g.createChild("Label")
        sign.height = 30
        sign.vertAlign = "center"
        sign.wrap = false
        sign.font = MakeFont("pkg:/fonts/Outfit-Medium.ttf", 22)
        cells = g.createChild("Group")
        m.rows.push({ group: g, chanBg: chanBg, chanBar: chanBar, logo: logo, num: num, sign: sign, cells: cells, pool: [] })
    end for
end sub

function rowCell(row as Object, index as Integer) as Object
    while row.pool.count() <= index
        g = row.cells.createChild("Group")
        bg = g.createChild("Rectangle")
        bg.height = m.rowH
        title = g.createChild("Label")
        title.translation = [16, 8]
        title.height = 36
        title.vertAlign = "center"
        title.wrap = false
        title.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 28)
        subLabel = g.createChild("Label")
        subLabel.translation = [16, 44]
        subLabel.height = 28
        subLabel.vertAlign = "center"
        subLabel.wrap = false
        subLabel.font = MakeFont("pkg:/fonts/Outfit-Regular.ttf", 22)
        row.pool.push({ group: g, bg: bg, title: title, subLabel: subLabel })
    end while
    return row.pool[index]
end function

' ---------------------------------------------------------------------------
' Loading
' ---------------------------------------------------------------------------

sub onConfigReady()
    if m.top.config = invalid then return
    loadFeed()
end sub

sub loadFeed()
    m.top.loadingMessage = "Loading Cable TV…"
    m.epgById = {}
    m.gridTask = createObject("roSGNode", "PlexTask")
    m.gridTask.config = m.top.config
    m.gridTask.action = "sportsFeed"
    m.gridTask.observeField("response", "onFeedLoaded")
    m.gridTask.control = "RUN"
end sub

' Entertainment + Cartoons leave Live Sports and live here as cable channels
function isCableCategory(title as String) as Boolean
    key = LCase(title)
    return key = "entertainment" or key = "cartoons"
end function

sub onFeedLoaded()
    response = m.gridTask.response
    if response = invalid or response.ok <> true then
        m.top.loadingMessage = ""
        err = "Could not load cable channels"
        if response <> invalid and response.error <> invalid then err = response.error
        m.programTitle.text = "Guide unavailable"
        m.programSub.text = ""
        m.programMeta.text = ""
        m.programSummary.text = err
        showGuideStatus(err)
        return
    end if

    rows = response.rows
    if rows = invalid then rows = []

    m.allChannels = []
    m.categories = []
    channelNum = 1
    for each rowData in rows
        league = asString(rowData.title)
        if isCableCategory(league) then
            items = rowData.items
            if items = invalid then items = []
            sectionChannels = []
            for each item in items
                ch = makeChannel(item, league, channelNum)
                m.allChannels.push(ch)
                sectionChannels.push(ch)
                channelNum = channelNum + 1
            end for
            if sectionChannels.count() > 0 then
                m.categories.push({ title: prettyCategory(league), channels: sectionChannels })
            end if
        end if
    end for

    m.tabNames = ["All"]
    for each cat in m.categories
        m.tabNames.push(cat.title)
    end for
    rebuildTabChrome()

    if m.allChannels.count() = 0 then
        m.top.loadingMessage = ""
        showGuideStatus("No Entertainment or Cartoons channels in the feed")
        return
    end if

    ' Streams come from the sports feed; listings come from the EPG sidecar
    loadCableEpg()
end sub

sub loadCableEpg()
    cfg = m.top.config
    epgUrl = ""
    if cfg <> invalid and cfg.cableEpgUrl <> invalid then epgUrl = cfg.cableEpgUrl
    if epgUrl = "" then
        finishGuideLoad()
        return
    end if
    m.top.loadingMessage = "Loading listings…"
    m.epgTask = createObject("roSGNode", "PlexTask")
    m.epgTask.config = cfg
    m.epgTask.action = "cableEpg"
    m.epgTask.observeField("response", "onCableEpgLoaded")
    m.epgTask.control = "RUN"
end sub

sub onCableEpgLoaded()
    response = m.epgTask.response
    if response <> invalid and response.ok = true and response.skipped <> true then
        m.epgById = response.byId
        if m.epgById = invalid then m.epgById = {}
        applyEpgToChannels()
    end if
    ' Missing sidecar / failed fetch: keep 24/7 placeholders — sports feed still works
    finishGuideLoad()
end sub

sub applyEpgToChannels()
    if m.epgById = invalid then return
    for each ch in m.allChannels
        feedId = asString(ch.feedId)
        if feedId <> "" and m.epgById.DoesExist(feedId) then
            programs = m.epgById[feedId]
            if programs <> invalid and programs.count() > 0 then
                ch.rawPrograms = programs
                ch.hasEpg = true
            end if
        end if
    end for
end sub

sub finishGuideLoad()
    m.top.loadingMessage = ""
    showGuideStatus("")
    m.guideLoaded = true
    applyTab(0, true)
end sub

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

function makeChannel(item as Object, category as String, number as Integer) as Object
    title = asString(item.title)
    if title = "" then title = "Channel"
    logo = asString(item.hdPosterUrl)
    if logo = "" then logo = asString(item.hdBackdropUrl)
    summary = asString(item.description)
    if summary = "" then summary = category + " · 24/7"
    feedId = ""
    if item.id <> invalid then feedId = asString(item.id)
    ' Inline programs[] still work if present; sidecar overwrites in applyEpgToChannels
    rawPrograms = []
    if item.programs <> invalid then rawPrograms = item.programs
    return {
        key: asString(item.streamUrl) + "|" + title,
        feedId: feedId,
        number: StrI(number).Trim(),
        callSign: title,
        name: title,
        logo: logo,
        category: prettyCategory(category),
        summary: summary,
        item: item,
        rawPrograms: rawPrograms,
        hasEpg: (rawPrograms.count() > 0),
        programs: []
    }
end function

function gapProgram(b as Integer, e as Integer, title as String) as Object
    return {
        title: title,
        subtitle: "",
        summary: "",
        placeholder: true,
        beginsAt: b,
        endsAt: e,
        lb: b,
        art: "",
        episodeLabel: "",
        contentRating: "",
        isNew: false
    }
end function

' Tile the guide window so Left/Right always has a cell to land on
function fillPrograms(raw as Object, startAt as Integer, endAt as Integer) as Object
    out = []
    cursor = startAt
    if raw = invalid or raw.count() = 0 then
        out.push(gapProgram(startAt, endAt, "No guide data"))
        return out
    end if
    for each p in raw
        b = p.beginsAt
        e = p.endsAt
        if b <= 0 or e <= b then
            b = startAt
            e = endAt
        end if
        if e > cursor then
            if b > cursor + 120 then out.push(gapProgram(cursor, b, "No information"))
            if out.count() = 0 then
                p.lb = b
            else if b < cursor then
                p.lb = cursor
            else
                p.lb = b
            end if
            p.endsAt = e
            if p.beginsAt <= 0 then p.beginsAt = b
            if p.placeholder = invalid then p.placeholder = false
            out.push(p)
            cursor = e
            if cursor >= endAt then exit for
        end if
    end for
    if cursor < endAt then out.push(gapProgram(cursor, endAt, "No information"))
    return out
end function

' Furthest time the guide will show — end of sidecar listings, or 24h for 24/7-only
function computeLoadedEnd() as Integer
    endAt = m.minWin + m.winLen
    hasEpg = false
    for each ch in m.allChannels
        if ch.hasEpg = true and ch.rawPrograms <> invalid then
            for each p in ch.rawPrograms
                if p.endsAt > endAt then endAt = p.endsAt
                hasEpg = true
            end for
        end if
    end for
    if not hasEpg then return m.minWin + (24 * 3600)
    return endAt
end function

function maxWinStart() as Integer
    limit = m.loadedEnd - m.winLen
    if limit < m.minWin then return m.minWin
    return limit
end function

sub clampWinStart()
    if m.winStart < m.minWin then m.winStart = m.minWin
    maxStart = maxWinStart()
    if m.winStart > maxStart then m.winStart = maxStart
end sub

sub rebuildPrograms()
    m.loadedEnd = computeLoadedEnd()
    startAt = m.minWin
    endAt = m.loadedEnd
    if endAt <= startAt then endAt = startAt + m.winLen
    for each ch in m.allChannels
        if ch.hasEpg = true then
            ch.programs = fillPrograms(ch.rawPrograms, startAt, endAt)
        else
            ' Unmapped / not-yet-enriched channels stay one continuous block
            ch.programs = [{
                title: ch.name,
                subtitle: "24/7",
                summary: ch.summary,
                placeholder: false,
                beginsAt: startAt,
                endsAt: endAt,
                lb: startAt,
                art: ch.logo,
                episodeLabel: "",
                contentRating: "",
                isNew: false
            }]
        end if
    end for
    clampWinStart()
end sub

sub applyTab(index as Integer, force as Boolean)
    if index < 0 then index = 0
    if index >= m.tabNames.count() then index = 0
    if not force and index = m.tab then return
    m.tab = index
    paintTabs()

    if m.tab = 0 then
        m.channels = m.allChannels
    else
        catIdx = m.tab - 1
        if catIdx >= 0 and catIdx < m.categories.count() then
            m.channels = m.categories[catIdx].channels
        else
            m.channels = m.allChannels
        end if
    end if

    rebuildPrograms()
    m.focusCh = 0
    m.topRow = 0
    m.winStart = m.minWin
    refocusAnchor(nowSeconds())
    renderGrid()
    updateGridInfo()
end sub

sub showGuideStatus(text as String)
    m.guideStatus.text = text
    m.guideStatus.visible = (text <> "")
end sub

' ---------------------------------------------------------------------------
' Grid rendering
' ---------------------------------------------------------------------------

sub renderGrid()
    winEnd = m.winStart + m.winLen
    for k = 0 to m.slotLabels.count() - 1
        t = m.winStart + k * m.slotLen
        text = clockText(t, true)
        if dayKey(t) <> dayKey(nowSeconds()) and (k = 0 or localTime(t).GetHours() = 0 and localTime(t).GetMinutes() = 0) then
            text = dayLabel(t) + " " + text
        end if
        m.slotLabels[k].text = text
    end for

    gridFocused = (m.zone = "grid")
    for r = 0 to m.rows.count() - 1
        row = m.rows[r]
        idx = m.topRow + r
        if idx >= m.channels.count() then
            row.group.visible = false
        else
            row.group.visible = true
            ch = m.channels[idx]
            focusRow = (idx = m.focusCh)
            paintChannel(row, ch, focusRow and gridFocused)
            used = 0
            for pi = 0 to ch.programs.count() - 1
                p = ch.programs[pi]
                if p.lb >= winEnd then exit for
                if p.endsAt > m.winStart then
                    x0 = p.lb
                    if x0 < m.winStart then x0 = m.winStart
                    x1 = p.endsAt
                    if x1 > winEnd then x1 = winEnd
                    px = Int((x0 - m.winStart) * m.pxPerSec)
                    pw = Int((x1 - m.winStart) * m.pxPerSec) - px - 4
                    if pw >= 4 then
                        cell = rowCell(row, used)
                        used = used + 1
                        paintCell(cell, p, px, pw, focusRow and pi = m.focusProg and gridFocused, p.lb < m.winStart)
                    end if
                end if
            end for
            for ci = used to row.pool.count() - 1
                row.pool[ci].group.visible = false
            end for
        end if
    end for
    paintNowLine()
end sub

sub paintChannel(row as Object, ch as Object, focused as Boolean)
    if focused then
        row.chanBg.color = "0x1E2738"
    else
        row.chanBg.color = "0x111725"
    end if
    row.chanBar.visible = focused
    textX = m.chanX + 18
    textW = m.chanW - 30
    if ch.logo <> invalid and ch.logo <> "" then
        row.logo.visible = true
        if row.logo.uri <> ch.logo then row.logo.uri = ch.logo
        textX = m.chanX + 122
        textW = m.chanW - 132
    else
        row.logo.visible = false
    end if
    row.num.text = ch.number
    row.sign.text = ch.callSign
    row.num.width = textW
    row.sign.width = textW
    row.num.translation = [textX, 6]
    row.sign.translation = [textX, 44]
    row.sign.visible = true
    if focused then
        row.num.color = "0xFFFFFF"
        row.sign.color = "0xC5CCD8"
    else
        row.num.color = "0xD5DBE6"
        row.sign.color = "0x8FA0B8"
    end if
end sub

sub paintCell(cell as Object, p as Object, x as Integer, w as Integer, focused as Boolean, clippedLeft as Boolean)
    cell.group.visible = true
    cell.group.translation = [m.progX + x, 0]
    cell.bg.width = w
    live = isOnNow(p)
    if focused then
        cell.bg.color = "0xEDF0F5"
    else if p.placeholder = true then
        cell.bg.color = "0x0E131D"
    else if live then
        cell.bg.color = "0x1C2436"
    else
        cell.bg.color = "0x141A27"
    end if

    textW = w - 32
    if textW < 8 then textW = 8
    showText = (w >= 48)
    cell.title.visible = showText
    cell.subLabel.visible = showText and w >= 120
    cell.title.width = textW
    cell.subLabel.width = w - 32

    title = p.title
    if clippedLeft then title = "« " + title
    cell.title.text = title
    subText = ""
    if p.placeholder <> true then
        subText = joinStrings([valueOr(p.episodeLabel, ""), valueOr(p.subtitle, "")], "  ·  ")
    end if
    cell.subLabel.text = subText

    if focused then
        cell.title.color = "0x0A0E18"
        cell.subLabel.color = "0x3A4458"
    else if p.placeholder = true then
        cell.title.color = "0x5E6880"
        cell.subLabel.color = "0x5E6880"
    else
        cell.title.color = "0xE8EEF8"
        cell.subLabel.color = "0x8FA0B8"
    end if
end sub

sub paintNowLine()
    t = nowSeconds()
    winEnd = m.winStart + m.winLen
    if t >= m.winStart and t < winEnd and m.guideLoaded then
        nx = Int((t - m.winStart) * m.pxPerSec)
        m.nowLine.translation = [m.progX + nx, 392]
        m.nowLine.visible = true
        m.pastShade.width = nx
        m.pastShade.visible = nx > 0
    else
        m.nowLine.visible = false
        m.pastShade.visible = false
    end if
end sub

' ---------------------------------------------------------------------------
' Focus / navigation
' ---------------------------------------------------------------------------

function focusedChannel() as Dynamic
    if m.focusCh < 0 or m.focusCh >= m.channels.count() then return invalid
    return m.channels[m.focusCh]
end function

function focusedProgram() as Dynamic
    ch = focusedChannel()
    if ch = invalid then return invalid
    if m.focusProg < 0 or m.focusProg >= ch.programs.count() then return invalid
    return ch.programs[m.focusProg]
end function

function programIndexAt(ch as Object, t as Integer) as Integer
    if ch = invalid or ch.programs.count() = 0 then return 0
    for i = 0 to ch.programs.count() - 1
        p = ch.programs[i]
        if p.lb <= t and p.endsAt > t then return i
    end for
    if t < ch.programs[0].lb then return 0
    return ch.programs.count() - 1
end function

sub refocusAnchor(t as Integer)
    m.anchor = t
    m.focusProg = programIndexAt(focusedChannel(), t)
end sub

sub setAnchorFromFocus()
    p = focusedProgram()
    if p = invalid then return
    a = p.lb
    if a < m.winStart then a = m.winStart
    if a < nowSeconds() and p.endsAt > nowSeconds() then a = nowSeconds()
    m.anchor = a
end sub

sub moveVertical(delta as Integer)
    count = m.channels.count()
    if count = 0 then return
    target = m.focusCh + delta
    if target < 0 then target = 0
    if target > count - 1 then target = count - 1
    if target = m.focusCh then return
    m.focusCh = target
    if m.focusCh < m.topRow then m.topRow = m.focusCh
    if m.focusCh > m.topRow + m.visibleRows - 1 then m.topRow = m.focusCh - m.visibleRows + 1
    m.focusProg = programIndexAt(focusedChannel(), m.anchor)
    afterFocusMove()
end sub

sub pageVertical(delta as Integer)
    count = m.channels.count()
    if count = 0 then return
    target = m.focusCh + delta
    if target < 0 then target = 0
    if target > count - 1 then target = count - 1
    if target = m.focusCh then return
    m.topRow = m.topRow + delta
    maxTop = count - m.visibleRows
    if maxTop < 0 then maxTop = 0
    if m.topRow > maxTop then m.topRow = maxTop
    if m.topRow < 0 then m.topRow = 0
    m.focusCh = target
    if m.focusCh < m.topRow then m.topRow = m.focusCh
    if m.focusCh > m.topRow + m.visibleRows - 1 then m.topRow = m.focusCh - m.visibleRows + 1
    m.focusProg = programIndexAt(focusedChannel(), m.anchor)
    afterFocusMove()
end sub

sub moveRight()
    ch = focusedChannel()
    if ch = invalid then return
    nextIdx = m.focusProg + 1
    if nextIdx >= ch.programs.count() then return
    nextProg = ch.programs[nextIdx]
    ' Don't step onto trailing empty guide padding past real listings
    if nextProg.placeholder = true and nextProg.lb >= m.loadedEnd - 60 then return
    if nextProg.lb >= m.loadedEnd then return

    m.focusProg = nextIdx
    p = ch.programs[nextIdx]
    while p.lb >= m.winStart + m.winLen - m.slotLen
        if m.winStart >= maxWinStart() then exit while
        m.winStart = m.winStart + m.slotLen
    end while
    clampWinStart()
    setAnchorFromFocus()
    afterFocusMove()
end sub

function moveLeft() as Boolean
    ch = focusedChannel()
    p = focusedProgram()
    if ch = invalid or p = invalid then return false
    if p.lb < m.winStart and m.winStart > m.minWin then
        m.winStart = m.winStart - m.slotLen
        if m.winStart < m.minWin then m.winStart = m.minWin
        setAnchorFromFocus()
        afterFocusMove()
        return true
    end if
    prevIdx = m.focusProg - 1
    if prevIdx < 0 or ch.programs[prevIdx].endsAt <= m.minWin then return false
    m.focusProg = prevIdx
    pp = ch.programs[prevIdx]
    while pp.lb < m.winStart and m.winStart > m.minWin
        m.winStart = m.winStart - m.slotLen
    end while
    if m.winStart < m.minWin then m.winStart = m.minWin
    setAnchorFromFocus()
    afterFocusMove()
    return true
end function

sub afterFocusMove()
    renderGrid()
    updateGridInfo()
end sub

' ---------------------------------------------------------------------------
' Info panel
' ---------------------------------------------------------------------------

sub clearBadges()
    while m.badgeRow.getChildCount() > 0
        m.badgeRow.removeChildIndex(0)
    end while
end sub

function addBadge(x as Integer, text as String, fill as String, ink as String) as Integer
    w = 24 + Len(text) * 14
    bg = m.badgeRow.createChild("Rectangle")
    bg.translation = [x, 2]
    bg.width = w
    bg.height = 32
    bg.color = fill
    lbl = m.badgeRow.createChild("Label")
    lbl.translation = [x, 2]
    lbl.width = w
    lbl.height = 32
    lbl.horizAlign = "center"
    lbl.vertAlign = "center"
    lbl.color = ink
    lbl.text = text
    lbl.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 20)
    return x + w + 10
end function

sub setArt(uri as String)
    if uri = invalid then uri = ""
    if m.heroArt.uri <> uri then m.heroArt.uri = uri
    if m.previewArt.uri <> uri then m.previewArt.uri = uri
    m.previewHint.visible = (uri = "")
end sub

sub paintInfo(title as String, subText as String, meta as String, summary as String, badges as Object, art as String)
    m.programTitle.text = title
    m.programSub.text = subText
    clearBadges()
    x = 0
    for each b in badges
        x = addBadge(x, b.text, b.fill, b.ink)
    end for
    if x > 0 then x = x + 4
    m.programMeta.translation = [x, 186]
    m.programMeta.width = 1240 - x
    m.programMeta.text = meta
    m.programSummary.text = summary
    setArt(art)
end sub

function channelLabel(ch as Object) as String
    if ch = invalid then return ""
    parts = []
    if ch.number <> invalid and ch.number <> "" then parts.push(ch.number)
    if ch.callSign <> invalid and ch.callSign <> "" then parts.push(ch.callSign)
    return joinStrings(parts, " ")
end function

sub updateGridInfo()
    ch = focusedChannel()
    p = focusedProgram()
    if ch = invalid or p = invalid then return

    badges = []
    live = isOnNow(p)
    if live and p.placeholder <> true then badges.push({ text: "LIVE", fill: "0xE50914", ink: "0xFFFFFF" })

    metaParts = [channelLabel(ch)]
    if ch.category <> invalid and ch.category <> "" then metaParts.push(ch.category)
    if p.placeholder <> true then
        when = rangeText(p.beginsAt, p.endsAt)
        if dayKey(p.beginsAt) <> dayKey(nowSeconds()) then when = dayLabel(p.beginsAt) + " " + when
        if when <> "" then metaParts.push(when)
        if p.year <> invalid and p.year <> "" then metaParts.push(p.year)
        if p.contentRating <> invalid and p.contentRating <> "" then metaParts.push(p.contentRating)
        if p.rating <> invalid and p.rating <> "" then metaParts.push(p.rating)
    else
        metaParts.push("No listing")
    end if

    subParts = []
    if p.episodeLabel <> invalid and p.episodeLabel <> "" then subParts.push(p.episodeLabel)
    if p.subtitle <> invalid and p.subtitle <> "" then subParts.push(p.subtitle)
    if subParts.count() = 0 and live then subParts.push("On now")

    summary = valueOr(p.summary, "")
    if p.placeholder = true then summary = "No program information for this time on " + channelLabel(ch) + "."
    if summary = "" then summary = ch.summary

    art = valueOr(p.backdrop, "")
    if art = "" then art = valueOr(p.art, "")
    if art = "" then art = valueOr(p.poster, "")
    if art = "" then art = ch.logo
    paintInfo(p.title, joinStrings(subParts, "  ·  "), joinStrings(metaParts, "  ·  "), summary, badges, art)
end sub

' ---------------------------------------------------------------------------
' Zones
' ---------------------------------------------------------------------------

sub enterTabs()
    m.zone = "tabs"
    paintTabs()
    m.top.setFocus(true)
    renderGrid()
end sub

sub enterContent()
    m.zone = "grid"
    paintTabs()
    m.top.setFocus(true)
    renderGrid()
    updateGridInfo()
end sub

sub leaveToMenu()
    m.top.openMenu = true
end sub

sub onRefocus()
    if m.top.refocus <> true then return
    m.top.setFocus(true)
    paintTabs()
    renderGrid()
end sub

' ---------------------------------------------------------------------------
' Watch
' ---------------------------------------------------------------------------

sub watchChannel(ch as Object)
    if ch = invalid or ch.item = invalid then return
    item = ch.item
    p = focusedProgram()

    title = asString(item.title)
    description = asString(item.description)
    poster = asString(item.hdPosterUrl)
    backdrop = asString(item.hdBackdropUrl)
    year = ""
    contentRating = ""
    rating = ""
    cast = []
    shortTitle = title

    if p <> invalid and p.placeholder <> true then
        if asString(p.title) <> "" then
            shortTitle = asString(p.title)
            title = shortTitle + "  ·  " + asString(item.title)
        end if
        if asString(p.summary) <> "" then description = asString(p.summary)
        if asString(p.poster) <> "" then poster = asString(p.poster)
        if asString(p.backdrop) <> "" then backdrop = asString(p.backdrop)
        if backdrop = "" and asString(p.art) <> "" then backdrop = asString(p.art)
        if poster = "" and asString(p.art) <> "" then poster = asString(p.art)
        year = asString(p.year)
        contentRating = asString(p.contentRating)
        rating = asString(p.rating)
        if p.cast <> invalid then cast = p.cast
    end if
    if poster = "" then poster = asString(item.hdPosterUrl)
    if backdrop = "" then backdrop = poster

    ' Direct HLS like sports, but carry TMDB/EPG chrome for the custom player
    m.top.selectedItem = {
        title: title,
        shortTitle: shortTitle,
        description: description,
        mediaType: "sport",
        ratingKey: "",
        key: asString(item.streamUrl),
        streamUrl: asString(item.streamUrl),
        streamFormat: asString(item.streamFormat),
        streams: item.streams,
        streamCount: item.streamCount,
        hdPosterUrl: poster,
        hdBackdropUrl: backdrop,
        year: year,
        contentRating: contentRating,
        rating: rating,
        cast: cast,
        duration: 0,
        viewOffset: 0
    }
end sub

' ---------------------------------------------------------------------------
' Remote
' ---------------------------------------------------------------------------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.zone = "tabs" then
        if key = "left" then
            if m.tab = 0 then
                leaveToMenu()
            else
                applyTab(m.tab - 1, false)
            end if
            return true
        else if key = "right" then
            if m.tab < m.tabNames.count() - 1 then applyTab(m.tab + 1, false)
            return true
        else if key = "down" or key = "OK" then
            enterContent()
            return true
        else if key = "back" then
            leaveToMenu()
            return true
        end if
        return true
    end if

    if not m.guideLoaded then
        if key = "up" then
            enterTabs()
            return true
        end if
        if key = "back" or key = "left" then
            leaveToMenu()
            return true
        end if
        return true
    end if

    if key = "up" then
        if m.focusCh = 0 then
            enterTabs()
        else
            moveVertical(-1)
        end if
        return true
    else if key = "down" then
        moveVertical(1)
        return true
    else if key = "right" then
        moveRight()
        return true
    else if key = "left" then
        if not moveLeft() then leaveToMenu()
        return true
    else if key = "fastforward" then
        pageVertical(m.visibleRows)
        return true
    else if key = "rewind" then
        pageVertical(-m.visibleRows)
        return true
    else if key = "OK" or key = "play" then
        watchChannel(focusedChannel())
        return true
    else if key = "back" then
        ' First Back → filter tabs; Back again from tabs opens the sidebar
        enterTabs()
        return true
    end if
    return false
end function

' ---------------------------------------------------------------------------
' Utils
' ---------------------------------------------------------------------------

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for each part in parts
        if part <> invalid and part <> "" then
            if out <> "" then out = out + sep
            out = out + part
        end if
    end for
    return out
end function

function valueOr(value as Dynamic, fallback as String) as String
    if value = invalid then return fallback
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    return fallback
end function

function asString(value as Dynamic) as String
    return valueOr(value, "")
end function
