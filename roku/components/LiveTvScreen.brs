sub init()
    m.programTitle = m.top.findNode("programTitle")
    m.programSub = m.top.findNode("programSub")
    m.programMeta = m.top.findNode("programMeta")
    m.programSummary = m.top.findNode("programSummary")
    m.badgeRow = m.top.findNode("badgeRow")
    m.progressGroup = m.top.findNode("progressGroup")
    m.progressFill = m.top.findNode("progressFill")
    m.progressLabel = m.top.findNode("progressLabel")
    m.heroArt = m.top.findNode("heroArt")
    m.tabRow = m.top.findNode("tabRow")

    m.previewArt = m.top.findNode("previewArt")
    m.previewVideo = m.top.findNode("previewVideo")
    m.previewHint = m.top.findNode("previewHint")
    m.previewTag = m.top.findNode("previewTag")
    m.previewTagLabel = m.top.findNode("previewTagLabel")

    m.guideView = m.top.findNode("guideView")
    m.clockLabel = m.top.findNode("clockLabel")
    m.slotHeader = m.top.findNode("slotHeader")
    m.gridRows = m.top.findNode("gridRows")
    m.pastShade = m.top.findNode("pastShade")
    m.nowLine = m.top.findNode("nowLine")
    m.guideStatus = m.top.findNode("guideStatus")

    m.dvrView = m.top.findNode("dvrView")
    m.dvrList = m.top.findNode("dvrList")
    m.dvrEmpty = m.top.findNode("dvrEmpty")
    m.dvrHeads = [m.top.findNode("dvrHead0"), m.top.findNode("dvrHead1"), m.top.findNode("dvrHead2"), m.top.findNode("dvrHead3")]

    m.menu = m.top.findNode("menu")
    m.menuPanel = m.top.findNode("menuPanel")
    m.menuAccent = m.top.findNode("menuAccent")
    m.menuTitle = m.top.findNode("menuTitle")
    m.menuSub = m.top.findNode("menuSub")
    m.menuList = m.top.findNode("menuList")
    m.toast = m.top.findNode("toast")
    m.toastLabel = m.top.findNode("toastLabel")

    ' Grid geometry (mirrors LiveTvScreen.xml)
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
    m.chunkLen = 4 * 3600
    m.maxAhead = 24 * 3600

    m.channels = []
    m.byKey = {}
    m.ctx = invalid
    m.loadedStart = 0
    m.loadedEnd = 0
    m.loadingMore = false
    m.guideLoaded = false
    m.focusCh = 0
    m.focusProg = 0
    m.topRow = 0
    m.anchor = 0
    m.minWin = floorSlot(nowSeconds())
    m.winStart = m.minWin
    m.rows = []
    m.slotLabels = []
    m.slotTicks = []

    m.tabNames = ["Guide", "Upcoming", "Rules"]
    m.tab = 0
    m.zone = "grid"
    m.tabsBuiltForKids = invalid
    m.schedule = { upcoming: [], rules: [] }
    m.recByAiring = {}
    m.recByGuid = {}
    m.seriesByGuid = {}
    m.dvrItems = []
    m.menuActions = []
    m.menuReturnZone = "grid"
    m.ruleEdit = invalid
    m.menuListY = 412
    m.previewKey = ""
    m.previewUrl = ""
    m.watching = invalid
    m.pendingWatch = invalid
    m.ownedLive = invalid
    m.plexChannels = []
    m.cableChannels = []
    m.cableLoading = false
    m.feedDialog = invalid
    m.feedDialogActions = []
    m.cableLineup = loadCableLineup()
    m.cableFallbackNum = 800

    buildTabs()
    buildSlotHeader()
    buildRows()

    m.dvrList.observeField("itemFocused", "onDvrFocused")
    m.dvrList.observeField("itemSelected", "onDvrSelected")
    m.dvrList.observeField("escapeUp", "onDvrEscapeUp")
    m.dvrList.observeField("escapeLeft", "onEscapeToMenu")
    m.dvrList.observeField("escapeBack", "onDvrEscapeBack")
    m.menuList.observeField("itemSelected", "onMenuSelected")

    m.clockTimer = createObject("roSGNode", "Timer")
    m.clockTimer.repeat = true
    m.clockTimer.duration = 15
    m.clockTimer.observeField("fire", "onClockTick")
    m.clockTimer.control = "start"

    m.toastTimer = createObject("roSGNode", "Timer")
    m.toastTimer.repeat = false
    m.toastTimer.duration = 3
    m.toastTimer.observeField("fire", "onToastDone")

    m.previewHint.text = "PREVIEW"
    updateClock()
    paintTabs()
    renderGrid()
    showGuideStatus("Loading guide…")
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
    ' "7:00 – 8:00 PM" when both halves share AM/PM
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
    x = 220
    for i = 0 to m.tabNames.count() - 1
        w = 40 + Len(m.tabNames[i]) * 17
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
        lbl.text = m.tabNames[i]
        lbl.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 28)
        m.tabNodes.push({ bg: bg, label: lbl })
        x = x + w + 12
    end for
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
        rec = g.createChild("Label")
        rec.translation = [0, 8]
        rec.width = 64
        rec.height = 30
        rec.horizAlign = "right"
        rec.vertAlign = "center"
        rec.color = "0xE50914"
        rec.text = "REC"
        rec.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 20)
        row.pool.push({ group: g, bg: bg, title: title, subLabel: subLabel, rec: rec })
    end while
    return row.pool[index]
end function

' ---------------------------------------------------------------------------
' Loading
' ---------------------------------------------------------------------------

sub onConfigReady()
    if m.top.config = invalid then return
    if not ProfileAllowsPlexLiveTv(m.top.config) then
        ' Kids: Guide only — no Plex DVR Upcoming/Rules
        m.tabNames = ["Guide"]
        while m.tabRow.getChildCount() > 1
            m.tabRow.removeChildIndex(m.tabRow.getChildCount() - 1)
        end while
        m.tabNodes = []
        m.tab = 0
        buildTabs()
        paintTabs()
    end if
    loadGuide()
    loadSchedule()
end sub

sub loadGuide()
    m.top.loadingMessage = "Loading TV guide…"
    m.cableChannels = []
    ' Kids: skip Plex Live TV entirely — streaming Cable nets only
    if not ProfileAllowsPlexLiveTv(m.top.config) then
        m.plexChannels = []
        m.byKey = {}
        m.ctx = invalid
        m.loadedStart = m.minWin
        m.loadedEnd = m.minWin + m.chunkLen
        m.top.loadingMessage = "Loading channels…"
        loadCableChannels()
        return
    end if
    m.gridTask = createObject("roSGNode", "PlexTask")
    m.gridTask.config = m.top.config
    m.gridTask.action = "liveTvGrid"
    start = m.minWin
    m.gridTask.item = { fresh: true, startAt: start, endAt: start + m.chunkLen }
    m.gridTask.observeField("response", "onGuideLoaded")
    m.gridTask.control = "RUN"
end sub

sub onGuideLoaded()
    response = m.gridTask.response
    m.plexChannels = []
    m.byKey = {}
    m.ctx = invalid

    if response = invalid or response.ok <> true then
        err = "Could not load Plex channels"
        if response <> invalid and response.error <> invalid then err = response.error
        showToast(err)
        m.loadedStart = m.minWin
        m.loadedEnd = m.minWin + m.chunkLen
    else
        m.ctx = { dvrId: response.dvrId, epgId: response.epgId, enabled: response.enabled }
        m.loadedStart = response.startAt
        m.loadedEnd = response.endAt
        for each ch in response.channels
            ch.source = "plex"
            ch.raw = ch.programs
            m.plexChannels.push(ch)
            m.byKey[ch.key] = ch
        end for
        if response.source = "fallback" then
            showToast("Plex guide data unavailable — showing channels only")
        end if
    end if

    ' Cable nets (Entertainment / Cartoons) load next and append into one lineup
    m.top.loadingMessage = "Loading cable channels…"
    loadCableChannels()
end sub

sub loadCableChannels()
    m.cableLoading = true
    m.cableFeedTask = createObject("roSGNode", "PlexTask")
    m.cableFeedTask.config = m.top.config
    m.cableFeedTask.action = "sportsFeed"
    m.cableFeedTask.observeField("response", "onCableFeedLoaded")
    m.cableFeedTask.control = "RUN"
end sub

function isCableCategory(title as String) as Boolean
    key = LCase(title)
    return key = "entertainment" or key = "cartoons"
end function

sub onCableFeedLoaded()
    response = m.cableFeedTask.response
    m.cableChannels = []
    if response = invalid or response.ok <> true then
        m.cableLoading = false
        finishUnifiedGuide()
        return
    end if

    rows = response.rows
    if rows = invalid then rows = []
    for each rowData in rows
        league = valueOr(rowData.title, "")
        if isCableCategory(league) then
            items = rowData.items
            if items = invalid then items = []
            for each item in items
                ch = makeCableChannel(item, league)
                if ch <> invalid then m.cableChannels.push(ch)
            end for
        end if
    end for

    cfg = m.top.config
    epgUrl = ""
    if cfg <> invalid and cfg.cableEpgUrl <> invalid then epgUrl = cfg.cableEpgUrl
    if epgUrl = "" or m.cableChannels.count() = 0 then
        m.cableLoading = false
        finishUnifiedGuide()
        return
    end if

    m.top.loadingMessage = "Loading cable listings…"
    m.cableEpgTask = createObject("roSGNode", "PlexTask")
    m.cableEpgTask.config = cfg
    m.cableEpgTask.action = "cableEpg"
    m.cableEpgTask.observeField("response", "onCableEpgLoaded")
    m.cableEpgTask.control = "RUN"
end sub

sub onCableEpgLoaded()
    response = m.cableEpgTask.response
    if response <> invalid and response.ok = true and response.skipped <> true then
        byId = response.byId
        if byId = invalid then byId = {}
        for each ch in m.cableChannels
            feedId = valueOr(ch.feedId, "")
            if feedId <> "" and byId.DoesExist(feedId) then
                programs = byId[feedId]
                if programs <> invalid and programs.count() > 0 then
                    raw = []
                    for each p in programs
                        mapped = cableProgToGuide(p)
                        if mapped <> invalid then raw.push(mapped)
                    end for
                    if raw.count() > 0 then ch.raw = raw
                end if
            end if
        end for
    end if
    m.cableLoading = false
    finishUnifiedGuide()
end sub

function loadCableLineup() as Object
    out = {}
    raw = ReadAsciiFile("pkg:/source/cable_lineup.json")
    if raw = invalid or raw = "" then return out
    parsed = ParseJson(raw)
    if parsed = invalid or parsed.channels = invalid then return out
    channels = parsed.channels
    if GetInterface(channels, "ifAssociativeArray") = invalid then return out
    for each feedId in channels
        n = channels[feedId]
        if n <> invalid then out[feedId] = Int(n)
    end for
    return out
end function

function preferredCableNumber(feedId as String) as Integer
    if feedId <> "" and m.cableLineup <> invalid and m.cableLineup.DoesExist(feedId) then
        return m.cableLineup[feedId]
    end if
    n = m.cableFallbackNum
    m.cableFallbackNum = m.cableFallbackNum + 1
    return n
end function

function makeCableChannel(item as Object, category as String) as Dynamic
    if item = invalid then return invalid
    title = valueOr(item.title, "")
    if title = "" then title = "Channel"
    logo = valueOr(item.hdPosterUrl, "")
    if logo = "" then logo = valueOr(item.hdBackdropUrl, "")
    feedId = valueOr(item.id, "")
    streamUrl = valueOr(item.streamUrl, "")
    if streamUrl = "" then return invalid
    key = "cable:" + feedId
    if feedId = "" then key = "cable:" + streamUrl
    number = preferredCableNumber(feedId)
    raw = []
    if item.programs <> invalid then
        for each p in item.programs
            mapped = cableProgToGuide(p)
            if mapped <> invalid then raw.push(mapped)
        end for
    end if
    return {
        key: key,
        source: "cable",
        feedId: feedId,
        number: "",
        sortKey: number * 1.0,
        callSign: title,
        name: title,
        logo: logo,
        summary: valueOr(item.description, category + " · 24/7"),
        tuneId: "",
        tuneAlt: "",
        streamUrl: streamUrl,
        streamFormat: valueOr(item.streamFormat, "hls"),
        item: item,
        programs: [],
        raw: raw
    }
end function

function cableProgToGuide(p as Object) as Dynamic
    if p = invalid then return invalid
    beginsAt = 0
    endsAt = 0
    if p.beginsAt <> invalid then beginsAt = p.beginsAt
    if p.endsAt <> invalid then endsAt = p.endsAt
    if beginsAt <= 0 or endsAt <= beginsAt then return invalid
    art = valueOr(p.art, "")
    if art = "" then art = valueOr(p.backdrop, "")
    if art = "" then art = valueOr(p.poster, "")
    kind = valueOr(p.tmdbType, "")
    if kind = "tv" then kind = "episode"
    return {
        title: valueOr(p.title, "Program"),
        subtitle: valueOr(p.subtitle, ""),
        summary: valueOr(p.summary, ""),
        placeholder: false,
        beginsAt: beginsAt,
        endsAt: endsAt,
        guid: "",
        showGuid: "",
        episodeLabel: valueOr(p.episodeLabel, ""),
        isNew: false,
        kind: kind,
        art: art,
        year: valueOr(p.year, ""),
        contentRating: valueOr(p.contentRating, ""),
        rating: valueOr(p.rating, ""),
        cast: p.cast,
        poster: valueOr(p.poster, ""),
        backdrop: valueOr(p.backdrop, "")
    }
end function

sub finishUnifiedGuide()
    m.top.loadingMessage = ""
    m.channels = []
    m.byKey = {}
    usedNumbers = {}
    allowPlex = ProfileAllowsPlexLiveTv(m.top.config)
    if allowPlex then
        for each ch in m.plexChannels
            ch.sortKey = channelSortKey(ch)
            markUsedNumber(usedNumbers, ch.sortKey)
            m.channels.push(ch)
            m.byKey[ch.key] = ch
        end for
    end if
    for each ch in m.cableChannels
        if ProfileAllowsCableChannel(m.top.config, valueOr(ch.feedId, ""), valueOr(ch.callSign, "")) then
            ' Keep lineup.json numbers so Cable sits among Plex locals/VCNs.
            ' Number column stays blank (name only); collisions are fine for sort.
            if ch.sortKey = invalid then ch.sortKey = channelSortKey(ch)
            ch.number = ""
            m.channels.push(ch)
            m.byKey[ch.key] = ch
        end if
    end for
    sortChannelsByNumber()
    rebuildPrograms()

    if m.channels.count() = 0 then
        m.guideLoaded = false
        showGuideStatus("No channels in the guide")
        m.programTitle.text = "Guide unavailable"
        return
    end if

    showGuideStatus("")
    m.guideLoaded = true
    if m.focusCh >= m.channels.count() then m.focusCh = 0
    if m.topRow >= m.channels.count() then m.topRow = 0
    m.winStart = m.minWin
    refocusAnchor(nowSeconds())
    renderGrid()
    updateGridInfo()
end sub

function channelSortKey(ch as Object) as Float
    if ch = invalid then return 99999.0
    if ch.sortKey <> invalid then return ch.sortKey
    n = valueOr(ch.number, "")
    if n = "" then return 99999.0
    return Val(n)
end function

sub markUsedNumber(used as Object, key as Float)
    ' Track whole-number slots so Cable 210 doesn't sit on top of Plex "210"
    slot = Int(key)
    used[StrI(slot).Trim()] = true
end sub

function avoidNumberCollision(used as Object, preferred as Float) as Float
    slot = Int(preferred)
    if slot < 1 then slot = 1
    guard = 0
    while used.DoesExist(StrI(slot).Trim()) and guard < 200
        slot = slot + 1
        guard = guard + 1
    end while
    return slot * 1.0
end function

function formatChannelNumber(key as Float) as String
    ' Prefer whole numbers for Cable; keep decimals for Plex VCNs like 7.1
    whole = Int(key)
    if Abs(key - whole) < 0.001 then return StrI(whole).Trim()
    text = Str(key).Trim()
    return text
end function

sub sortChannelsByNumber()
    n = m.channels.count()
    if n < 2 then return
    for i = 0 to n - 2
        best = i
        bestKey = channelSortKey(m.channels[i])
        for j = i + 1 to n - 1
            k = channelSortKey(m.channels[j])
            if k < bestKey then
                best = j
                bestKey = k
            end if
        end for
        if best <> i then
            tmp = m.channels[i]
            m.channels[i] = m.channels[best]
            m.channels[best] = tmp
        end if
    end for
end sub

sub maybeLoadMore()
    ' Only Plex EPG pages forward; cable listings come from the sidecar window
    if not m.guideLoaded or m.loadingMore or m.ctx = invalid then return
    if m.loadedEnd >= nowSeconds() + m.maxAhead then return
    if m.winStart + m.winLen + 3600 < m.loadedEnd then return
    m.loadingMore = true
    m.moreTask = createObject("roSGNode", "PlexTask")
    m.moreTask.config = m.top.config
    m.moreTask.action = "liveTvGrid"
    m.moreTask.item = {
        dvrId: m.ctx.dvrId,
        epgId: m.ctx.epgId,
        enabled: m.ctx.enabled,
        startAt: m.loadedEnd,
        endAt: m.loadedEnd + m.chunkLen
    }
    m.moreTask.observeField("response", "onMoreLoaded")
    m.moreTask.control = "RUN"
end sub

sub onMoreLoaded()
    m.loadingMore = false
    response = m.moreTask.response
    if response = invalid or response.ok <> true then return
    for each incoming in response.channels
        ch = m.byKey[incoming.key]
        if ch <> invalid and ch.source <> "cable" then
            lastBegin = 0
            if ch.raw.count() > 0 then lastBegin = ch.raw.peek().beginsAt
            for each p in incoming.programs
                if p.beginsAt > lastBegin then ch.raw.push(p)
            end for
        end if
    end for
    m.loadedEnd = response.endAt
    anchor = m.anchor
    rebuildPrograms()
    refocusAnchor(anchor)
    renderGrid()
    if m.zone = "grid" then updateGridInfo()
end sub

sub rebuildPrograms()
    for each ch in m.channels
        ch.programs = fillPrograms(ch.raw, m.loadedStart, m.loadedEnd)
    end for
end sub

function gapProgram(b as Integer, e as Integer, title as String) as Object
    return { title: title, subtitle: "", summary: "", placeholder: true, beginsAt: b, endsAt: e, lb: b, guid: "", showGuid: "", episodeLabel: "", isNew: false, kind: "", art: "" }
end function

' Guide rows must tile the loaded window so Left/Right always has a target
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
            ' Channel-only fallback: one block for whatever is on
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
            out.push(p)
            cursor = e
            if cursor >= endAt then exit for
        end if
    end for
    if cursor < endAt then out.push(gapProgram(cursor, endAt, "No information"))
    return out
end function

sub showGuideStatus(text as String)
    m.guideStatus.text = text
    m.guideStatus.visible = (text <> "")
end sub

' ---------------------------------------------------------------------------
' DVR schedule
' ---------------------------------------------------------------------------

sub loadSchedule()
    if not ProfileAllowsPlexLiveTv(m.top.config) then
        m.schedule = { upcoming: [], rules: [] }
        m.recByAiring = {}
        m.recByGuid = {}
        m.seriesByGuid = {}
        return
    end if
    m.scheduleTask = createObject("roSGNode", "PlexTask")
    m.scheduleTask.config = m.top.config
    m.scheduleTask.action = "dvrSchedule"
    m.scheduleTask.observeField("response", "onScheduleLoaded")
    m.scheduleTask.control = "RUN"
end sub

sub onScheduleLoaded()
    response = m.scheduleTask.response
    if response = invalid or response.ok <> true then
        m.schedule = { upcoming: [], rules: [], error: "" }
        if response <> invalid and response.error <> invalid then m.schedule.error = response.error
    else
        m.schedule = response
    end if
    m.recByAiring = {}
    m.recByGuid = {}
    m.seriesByGuid = {}
    for each up in m.schedule.upcoming
        if up.channelKey <> "" and up.beginsAt > 0 then m.recByAiring[up.channelKey + "|" + StrI(up.beginsAt).Trim()] = up
        if up.guid <> "" then m.recByGuid[up.guid + "|" + StrI(up.beginsAt).Trim()] = up
        if up.subscriptionType = 2 and up.showGuid <> "" then m.seriesByGuid[up.showGuid] = up.subscriptionId
    end for
    for each rule in m.schedule.rules
        if rule.type = 2 and rule.guid <> "" then m.seriesByGuid[rule.guid] = rule.id
    end for
    renderGrid()
    if m.zone = "grid" then updateGridInfo()
    if m.tab > 0 then fillDvrList(true)
end sub

function recordingFor(ch as Object, p as Object) as Dynamic
    if p = invalid or p.placeholder = true then return invalid
    stamp = StrI(p.beginsAt).Trim()
    if ch <> invalid and m.recByAiring.DoesExist(ch.key + "|" + stamp) then return m.recByAiring[ch.key + "|" + stamp]
    if p.guid <> "" and m.recByGuid.DoesExist(p.guid + "|" + stamp) then return m.recByGuid[p.guid + "|" + stamp]
    return invalid
end function

function seriesRuleFor(p as Object) as String
    if p = invalid or p.showGuid = invalid or p.showGuid = "" then return ""
    if m.seriesByGuid.DoesExist(p.showGuid) then return m.seriesByGuid[p.showGuid]
    return ""
end function

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
                        paintCell(cell, ch, p, px, pw, focusRow and pi = m.focusProg and gridFocused, p.lb < m.winStart)
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
    number = ch.number
    sign = ch.callSign
    if number = "" then
        number = sign
        sign = ""
        if ch.name <> invalid and ch.name <> number then sign = ch.name
    end if
    row.num.text = number
    row.sign.text = sign
    row.num.width = textW
    row.sign.width = textW
    if sign = "" then
        row.num.translation = [textX, 21]
    else
        row.num.translation = [textX, 6]
    end if
    row.sign.translation = [textX, 44]
    row.sign.visible = (sign <> "")
    if focused then
        row.num.color = "0xFFFFFF"
        row.sign.color = "0xC5CCD8"
    else
        row.num.color = "0xD5DBE6"
        row.sign.color = "0x8FA0B8"
    end if
end sub

sub paintCell(cell as Object, ch as Object, p as Object, x as Integer, w as Integer, focused as Boolean, clippedLeft as Boolean)
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

    rec = recordingFor(ch, p)
    marked = (rec <> invalid) or (seriesRuleFor(p) <> "")
    textW = w - 32
    if marked and w > 140 then textW = w - 96
    showText = (w >= 48)
    cell.title.visible = showText
    cell.subLabel.visible = showText and w >= 120
    cell.rec.visible = marked and w > 140
    if marked then
        cell.rec.translation = [w - 76, 8]
        if rec <> invalid then cell.rec.text = "REC" else cell.rec.text = "SERIES"
    end if
    if textW < 8 then textW = 8
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
' Grid focus / navigation
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
    afterFocusMove(true)
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
    afterFocusMove(true)
end sub

sub moveRight()
    ch = focusedChannel()
    if ch = invalid then return
    nextIdx = m.focusProg + 1
    if nextIdx >= ch.programs.count() then
        maybeLoadMore()
        return
    end if
    m.focusProg = nextIdx
    p = ch.programs[nextIdx]
    ' Page time forward once the next show starts in the last half hour
    while p.lb >= m.winStart + m.winLen - m.slotLen
        m.winStart = m.winStart + m.slotLen
    end while
    setAnchorFromFocus()
    maybeLoadMore()
    afterFocusMove(false)
end sub

function moveLeft() as Boolean
    ch = focusedChannel()
    p = focusedProgram()
    if ch = invalid or p = invalid then return false
    if p.lb < m.winStart and m.winStart > m.minWin then
        m.winStart = m.winStart - m.slotLen
        setAnchorFromFocus()
        afterFocusMove(false)
        return true
    end if
    prevIdx = m.focusProg - 1
    if prevIdx < 0 or ch.programs[prevIdx].endsAt <= m.minWin then return false
    m.focusProg = prevIdx
    pp = ch.programs[prevIdx]
    while pp.lb < m.winStart and m.winStart > m.minWin
        m.winStart = m.winStart - m.slotLen
    end while
    setAnchorFromFocus()
    afterFocusMove(false)
    return true
end function

sub afterFocusMove(channelChanged as Boolean)
    if channelChanged then dropStalePreview()
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
    if not m.previewVideo.visible then
        if m.previewArt.uri <> uri then m.previewArt.uri = uri
        m.previewHint.visible = (uri = "")
    end if
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
    if ch = invalid or p = invalid then
        m.progressGroup.visible = false
        return
    end if
    badges = []
    live = isOnNow(p)
    if live and p.placeholder <> true then badges.push({ text: "LIVE", fill: "0xE50914", ink: "0xFFFFFF" })
    if ch.source = "cable" then badges.push({ text: "CABLE", fill: "0x1A2438", ink: "0xC5CCD8" })
    if p.isNew = true then badges.push({ text: "NEW", fill: "0xEDF0F5", ink: "0x0A0E18" })
    rec = recordingFor(ch, p)
    if ch.source <> "cable" and rec <> invalid then
        badges.push({ text: "REC", fill: "0x3A0D12", ink: "0xFF5A64" })
    else if ch.source <> "cable" and seriesRuleFor(p) <> "" then
        badges.push({ text: "SERIES REC", fill: "0x3A0D12", ink: "0xFF5A64" })
    end if

    metaParts = [channelLabel(ch)]
    if p.placeholder <> true then
        when = rangeText(p.beginsAt, p.endsAt)
        if dayKey(p.beginsAt) <> dayKey(nowSeconds()) then when = dayLabel(p.beginsAt) + " " + when
        if when <> "" then metaParts.push(when)
        if p.contentRating <> invalid and p.contentRating <> "" then metaParts.push(p.contentRating)
    end if

    subParts = []
    if p.episodeLabel <> invalid and p.episodeLabel <> "" then subParts.push(p.episodeLabel)
    if p.subtitle <> invalid and p.subtitle <> "" then subParts.push(p.subtitle)

    summary = ""
    if p.summary <> invalid then summary = p.summary
    if p.placeholder = true then
        if ch.source = "cable" and valueOr(ch.summary, "") <> "" then
            summary = ch.summary
        else
            summary = "No program information for this time on " + channelLabel(ch) + "."
        end if
    end if
    title = p.title
    art = valueOr(p.art, "")
    if art = "" and ch.source = "cable" then art = valueOr(ch.logo, "")
    paintInfo(title, joinStrings(subParts, "  ·  "), joinStrings(metaParts, "  ·  "), summary, badges, art)

    if live and p.placeholder <> true and p.endsAt > p.beginsAt then
        t = nowSeconds()
        frac = (t - p.beginsAt) / (p.endsAt - p.beginsAt)
        if frac < 0 then frac = 0
        if frac > 1 then frac = 1
        m.progressFill.width = Int(360 * frac)
        minsLeft = Int((p.endsAt - t) / 60)
        m.progressLabel.text = StrI(minsLeft).Trim() + " min left"
        m.progressGroup.visible = true
        m.programSummary.translation = [0, 256]
    else
        m.progressGroup.visible = false
        m.programSummary.translation = [0, 236]
    end if

end sub

' ---------------------------------------------------------------------------
' Preview
' ---------------------------------------------------------------------------

' The preview square shows art; video only resumes there after Back from a
' full-screen channel, and moving to another channel ends that session
sub dropStalePreview()
    ch = focusedChannel()
    if not m.previewVideo.visible then return
    if ch <> invalid and ch.key = m.previewKey then return
    stopPreview()
    releaseOwnedLive()
end sub

sub stopPreview()
    if m.previewVideo <> invalid then
        m.previewVideo.control = "stop"
        m.previewVideo.visible = false
    end if
    m.previewKey = ""
    m.previewTag.visible = false
    m.previewTagLabel.visible = false
end sub

' Each tune holds a tuner until its temporary subscription is dropped, so the
' guide owns at most one live session at a time
sub adoptLive(key as String, response as Object)
    incoming = { key: key, subscriptionId: valueOr(response.subscriptionId, ""), session: valueOr(response.session, "") }
    if m.ownedLive <> invalid and m.ownedLive.subscriptionId <> incoming.subscriptionId then releaseLive(m.ownedLive)
    m.ownedLive = incoming
end sub

' Hands back the owned session for a tune task to release before tuning
' another channel; keeps it when re-tuning the same channel
function takeOwnedLive(key as String) as Dynamic
    if m.ownedLive = invalid or m.ownedLive.key = key then return invalid
    owned = m.ownedLive
    m.ownedLive = invalid
    return owned
end function

sub releaseLive(owned as Dynamic)
    if owned = invalid or m.top.config = invalid then return
    if valueOr(owned.subscriptionId, "") = "" and valueOr(owned.session, "") = "" then return
    task = createObject("roSGNode", "PlexTask")
    task.config = m.top.config
    task.action = "releaseLive"
    task.item = owned
    task.control = "RUN"
    m.releaseTask = task
end sub

sub releaseOwnedLive()
    if m.ownedLive = invalid then return
    releaseLive(m.ownedLive)
    m.ownedLive = invalid
end sub

sub playPreview(ch as Object, url as String)
    m.previewKey = ch.key
    m.previewUrl = url
    contentNode = createObject("roSGNode", "ContentNode")
    contentNode.url = url
    contentNode.streamFormat = "hls"
    contentNode.live = true
    cfg = m.top.config
    if cfg <> invalid then
        contentNode.HttpHeaders = [
            "X-Plex-Token:" + valueOr(cfg.token, ""),
            "X-Plex-Client-Identifier:" + valueOr(cfg.clientId, ""),
            "X-Plex-Product:" + valueOr(cfg.product, ""),
            "X-Plex-Platform:Roku",
            "X-Plex-Device:Roku"
        ]
    end if
    m.previewVideo.content = contentNode
    m.previewVideo.visible = true
    m.previewHint.visible = false
    m.previewTagLabel.text = "  LIVE  ·  " + channelLabel(ch)
    m.previewTag.width = 40 + Len(m.previewTagLabel.text) * 12
    m.previewTag.visible = true
    m.previewTagLabel.visible = true
    m.previewVideo.control = "play"
end sub

' ---------------------------------------------------------------------------
' Tabs + DVR lists
' ---------------------------------------------------------------------------

sub applyTab(index as Integer)
    if index = m.tab then return
    m.tab = index
    paintTabs()
    if m.tab = 0 then
        m.guideView.visible = true
        m.dvrView.visible = false
        renderGrid()
        updateGridInfo()
    else
        stopPreview()
        releaseOwnedLive()
        m.guideView.visible = false
        m.dvrView.visible = true
        fillDvrList(false)
        loadSchedule()
    end if
    ' Tab switches while the pills own the remote must not hand focus to the list
    if m.zone = "tabs" then m.top.setFocus(true)
end sub

sub setDvrRow(node as Object, c0 as String, c1 as String, c2 as String, c3 as String)
    node.title = c1
    node.addFields({ col0: c0, col1: c1, col2: c2, col3: c3 })
end sub

function upcomingStatus(up as Object) as String
    status = LCase(valueOr(up.status, ""))
    if status = "inprogress" or status = "recording" then return "Recording now"
    if status = "error" or status = "failed" then return "Failed"
    if status = "complete" or status = "completed" then return "Recorded"
    if up.subscriptionType = 2 then return "Series rule"
    return "Scheduled"
end function

sub fillDvrList(keepFocus as Boolean)
    root = createObject("roSGNode", "ContentNode")
    m.dvrItems = []
    if m.tab = 1 then
        heads = ["WHEN", "PROGRAM", "CHANNEL", "STATUS"]
        for each up in m.schedule.upcoming
            when = ""
            if up.beginsAt > 0 then when = dayLabel(up.beginsAt) + " " + clockText(up.beginsAt, true)
            name = up.title
            if up.episodeLabel <> invalid and up.episodeLabel <> "" then name = name + "  " + up.episodeLabel
            chan = joinStrings([valueOr(up.channelVcn, ""), valueOr(up.channelCallSign, "")], " ").Trim()
            setDvrRow(root.createChild("ContentNode"), when, name, chan, upcomingStatus(up))
            m.dvrItems.push({ kind: "upcoming", data: up })
        end for
        empty = "Nothing scheduled to record."
    else
        heads = ["SHOW", "", "RECORDING", "UPCOMING"]
        for each rule in m.schedule.rules
            countText = StrI(rule.count).Trim() + " upcoming"
            setDvrRow(root.createChild("ContentNode"), rule.title, "", rule.typeLabel, countText)
            m.dvrItems.push({ kind: "rule", data: rule })
        end for
        empty = "No recording rules yet."
    end if
    if m.schedule.error <> invalid and m.schedule.error <> "" and m.dvrItems.count() = 0 then empty = m.schedule.error
    for i = 0 to 3
        m.dvrHeads[i].text = heads[i]
    end for
    focusIdx = 0
    if keepFocus and m.dvrList.itemFocused <> invalid and m.dvrList.itemFocused >= 0 then focusIdx = m.dvrList.itemFocused
    if focusIdx >= m.dvrItems.count() then focusIdx = m.dvrItems.count() - 1
    if focusIdx < 0 then focusIdx = 0
    m.dvrList.content = root
    m.dvrEmpty.text = empty
    m.dvrEmpty.visible = (m.dvrItems.count() = 0)
    m.dvrList.visible = (m.dvrItems.count() > 0)
    if m.dvrItems.count() > 0 then
        m.dvrList.jumpToItem = focusIdx
        updateDvrInfo(focusIdx)
    else
        paintInfo(m.tabNames[m.tab], "", "", "", [], "")
        m.progressGroup.visible = false
    end if
    if m.zone = "list" then
        if m.dvrItems.count() > 0 then m.dvrList.setFocus(true) else enterTabs()
    end if
end sub

sub updateDvrInfo(idx as Integer)
    if idx < 0 or idx >= m.dvrItems.count() then return
    entry = m.dvrItems[idx]
    m.progressGroup.visible = false
    m.programSummary.translation = [0, 236]
    if entry.kind = "upcoming" then
        up = entry.data
        badges = []
        status = upcomingStatus(up)
        if status = "Recording now" then badges.push({ text: "REC", fill: "0xE50914", ink: "0xFFFFFF" })
        if up.isNew = true then badges.push({ text: "NEW", fill: "0xEDF0F5", ink: "0x0A0E18" })
        subParts = []
        if up.episodeLabel <> invalid and up.episodeLabel <> "" then subParts.push(up.episodeLabel)
        if up.subtitle <> invalid and up.subtitle <> "" then subParts.push(up.subtitle)
        meta = []
        chan = joinStrings([valueOr(up.channelVcn, ""), valueOr(up.channelCallSign, "")], " ").Trim()
        if chan <> "" then meta.push(chan)
        if up.beginsAt > 0 then meta.push(dayLabel(up.beginsAt) + " " + rangeText(up.beginsAt, up.endsAt))
        meta.push(status)
        paintInfo(up.title, joinStrings(subParts, "  ·  "), joinStrings(meta, "  ·  "), valueOr(up.summary, ""), badges, valueOr(up.art, ""))
    else
        rule = entry.data
        meta = [rule.typeLabel, StrI(rule.count).Trim() + " upcoming"]
        if valueOr(rule.library, "") <> "" then meta.push("Saves to " + rule.library)
        paintInfo(rule.title, valueOr(rule.airingsType, ""), joinStrings(meta, "  ·  "), valueOr(rule.summary, ""), [], valueOr(rule.art, ""))
    end if
end sub

sub onDvrFocused()
    idx = m.dvrList.itemFocused
    if idx = invalid then return
    updateDvrInfo(idx)
end sub

sub onDvrSelected()
    idx = m.dvrList.itemSelected
    if idx = invalid or idx < 0 or idx >= m.dvrItems.count() then return
    entry = m.dvrItems[idx]
    actions = []
    if entry.kind = "upcoming" then
        up = entry.data
        seriesId = seriesRuleIdForUpcoming(up)
        if seriesId <> "" then
            actions.push({ label: "Edit series rule", act: "editRule", data: seriesId })
            actions.push({ label: "Delete series rule", act: "confirmDelete", data: { subscriptionId: seriesId, title: up.title, done: "Series rule deleted" } })
        end if
        if seriesId <> up.subscriptionId then
            actions.push({ label: "Cancel recording", act: "cancel", data: { subscriptionId: up.subscriptionId, done: "Recording cancelled" } })
        end if
        subText = rangeText(up.beginsAt, up.endsAt)
        if up.beginsAt > 0 then subText = dayLabel(up.beginsAt) + " " + subText
        actions.push({ label: "Close", act: "close" })
        openActionMenu(up.title, subText, actions)
    else
        openRuleEditor(entry.data)
    end if
end sub

function ruleById(id as String) as Dynamic
    if id = invalid or id = "" then return invalid
    for each rule in m.schedule.rules
        if rule.id = id then return rule
    end for
    return invalid
end function

function seriesRuleIdForUpcoming(up as Object) as String
    if up.subscriptionType = 2 then return up.subscriptionId
    rule = ruleById(up.subscriptionId)
    if rule <> invalid and rule.type = 2 then return rule.id
    return seriesRuleFor(up)
end function

sub openRuleEditor(rule as Object)
    values = {}
    for each setting in nodeListOf(rule.settings)
        values[setting.id] = setting.value
    end for
    subParts = [rule.typeLabel]
    if valueOr(rule.library, "") <> "" then subParts.push("Saves to " + rule.library)
    m.ruleEdit = { mode: "edit", rule: rule, values: values, loading: false, picking: -1, title: rule.title, subText: joinStrings(subParts, "  ·  ") }
    if nodeListOf(rule.settings).count() = 0 and valueOr(rule.guid, "") <> "" then
        m.ruleEdit.loading = true
        m.ruleTask = createObject("roSGNode", "PlexTask")
        m.ruleTask.config = m.top.config
        m.ruleTask.action = "ruleSettings"
        m.ruleTask.item = { guid: rule.guid, type: rule.type, subscriptionId: rule.id }
        m.ruleTask.observeField("response", "onRuleSettings")
        m.ruleTask.control = "RUN"
    end if
    openActionMenu(rule.title, joinStrings(subParts, "  ·  "), ruleActions())
end sub

' Recording a show starts from the template's defaults so the full rule
' options can be set before Plex creates it
sub openRecordEditor(option as Object, title as String)
    rule = { id: "", title: title, type: option.type, typeLabel: option.label, settings: nodeListOf(option.settings), guid: "" }
    values = {}
    for each setting in rule.settings
        values[setting.id] = setting.value
    end for
    m.ruleEdit = { mode: "create", option: option, rule: rule, values: values, loading: false, picking: -1, title: title, subText: option.label }
    openActionMenu(title, option.label, ruleActions())
end sub

sub onRuleSettings()
    if m.ruleEdit = invalid or m.zone <> "menu" then return
    response = m.ruleTask.response
    if m.ruleEdit.picking >= 0 then return
    m.ruleEdit.loading = false
    if response <> invalid and response.ok = true then
        m.ruleEdit.rule.settings = response.settings
        for each setting in nodeListOf(response.settings)
            m.ruleEdit.values[setting.id] = setting.value
        end for
    end if
    setMenuActions(ruleActions())
end sub

sub editRuleById(id as String)
    for each rule in m.schedule.rules
        if rule.id = id then
            openRuleEditor(rule)
            return
        end if
    end for
    showToast("Rule not found — try again in a moment")
end sub

function nodeListOf(value as Dynamic) as Object
    if value = invalid or GetInterface(value, "ifArray") = invalid then return []
    return value
end function

function choiceIndex(setting as Object, value as String) as Integer
    for i = 0 to setting.choices.count() - 1
        if setting.choices[i].value = value then return i
    end for
    return 0
end function

function ruleActions() as Object
    actions = []
    if m.ruleEdit = invalid then return actions
    settings = nodeListOf(m.ruleEdit.rule.settings)
    for i = 0 to settings.count() - 1
        setting = settings[i]
        choice = setting.choices[choiceIndex(setting, m.ruleEdit.values[setting.id])]
        actions.push({ label: setting.label + ":   " + choice.label + "   ›", act: "pickSetting", data: i })
    end for
    if m.ruleEdit.loading = true then actions.push({ label: "Loading settings…", act: "none" })
    if m.ruleEdit.mode = "create" then
        actions.push({ label: "Record", act: "createRule" })
        actions.push({ label: "Cancel", act: "close" })
        return actions
    end if
    if settings.count() > 0 then actions.push({ label: "Save changes", act: "saveRule" })
    actions.push({ label: "Delete rule", act: "confirmDelete", data: { subscriptionId: m.ruleEdit.rule.id, title: m.ruleEdit.rule.title, done: "Rule deleted" } })
    actions.push({ label: "Close", act: "close" })
    return actions
end function

sub openSettingPicker(index as Integer)
    settings = nodeListOf(m.ruleEdit.rule.settings)
    if index < 0 or index >= settings.count() then return
    setting = settings[index]
    m.ruleEdit.picking = index
    current = choiceIndex(setting, m.ruleEdit.values[setting.id])
    actions = []
    for i = 0 to setting.choices.count() - 1
        mark = "     "
        if i = current then mark = "•   "
        actions.push({ label: mark + setting.choices[i].label, act: "choose", data: setting.choices[i].value })
    end for
    m.menuTitle.text = setting.label
    m.menuSub.text = m.ruleEdit.rule.title
    setMenuActions(actions)
    m.menuList.jumpToItem = current
end sub

sub closeSettingPicker(value as Dynamic)
    index = m.ruleEdit.picking
    m.ruleEdit.picking = -1
    settings = nodeListOf(m.ruleEdit.rule.settings)
    if value <> invalid and index >= 0 and index < settings.count() then
        m.ruleEdit.values[settings[index].id] = value
    end if
    m.menuTitle.text = m.ruleEdit.title
    m.menuSub.text = m.ruleEdit.subText
    setMenuActions(ruleActions())
    if index >= 0 then m.menuList.jumpToItem = index
end sub

sub saveRule()
    changed = {}
    for each setting in nodeListOf(m.ruleEdit.rule.settings)
        value = m.ruleEdit.values[setting.id]
        if value <> setting.value then changed[setting.id] = value
    end for
    ruleId = m.ruleEdit.rule.id
    closeActionMenu()
    if changed.count() = 0 then return
    runDvrCommand("ruleUpdate", { subscriptionId: ruleId, prefs: changed }, "Rule updated")
end sub

sub onDvrEscapeUp()
    enterTabs()
end sub

sub onDvrEscapeBack()
    enterTabs()
end sub

sub onEscapeToMenu()
    leaveToMenu()
end sub

' ---------------------------------------------------------------------------
' Zones
' ---------------------------------------------------------------------------

sub enterTabs()
    m.zone = "tabs"
    paintTabs()
    m.top.setFocus(true)
    if m.tab = 0 then renderGrid()
end sub

sub enterContent()
    paintTabs()
    if m.tab = 0 then
        m.zone = "grid"
        paintTabs()
        m.top.setFocus(true)
        renderGrid()
        updateGridInfo()
    else if m.dvrItems.count() > 0 then
        m.zone = "list"
        paintTabs()
        m.dvrList.setFocus(true)
    end if
end sub

sub leaveToMenu()
    stopPreview()
    releaseOwnedLive()
    m.top.openMenu = true
end sub

sub onRefocus()
    if m.top.refocus <> true then return
    if m.zone = "menu" then
        m.menuList.setFocus(true)
    else if m.zone = "list" and m.dvrItems.count() > 0 then
        m.dvrList.setFocus(true)
    else
        if m.zone = "list" then m.zone = "tabs"
        m.top.setFocus(true)
    end if
    paintTabs()
    if m.tab <> 0 then return
    resumed = m.watching
    m.watching = invalid
    if resumed <> invalid and m.byKey.DoesExist(resumed.key) then
        ' Back from full screen keeps the same live session going in the preview
        for i = 0 to m.channels.count() - 1
            if m.channels[i].key = resumed.key then
                if i <> m.focusCh then
                    m.focusCh = i
                    if m.focusCh < m.topRow or m.focusCh > m.topRow + m.visibleRows - 1 then m.topRow = m.focusCh
                    refocusAnchor(nowSeconds())
                end if
                exit for
            end if
        end for
        renderGrid()
        updateGridInfo()
        playPreview(m.channels[m.focusCh], resumed.url)
        return
    end if
    renderGrid()
end sub

' ---------------------------------------------------------------------------
' Watch / record
' ---------------------------------------------------------------------------

sub watchChannel(ch as Object, p as Dynamic)
    if ch = invalid then return
    if ch.source = "cable" then
        stopPreview()
        releaseOwnedLive()
        url = valueOr(ch.streamUrl, "")
        if url = "" then
            showToast("No stream for this channel")
            return
        end if
        launchWatch(ch, p, url)
        return
    end if
    if m.ctx = invalid then
        showToast("Plex Live TV is not available")
        return
    end if
    url = ""
    if m.previewKey = ch.key and m.previewVideo.visible and m.previewUrl <> invalid then url = m.previewUrl
    stopPreview()
    if url = "" then
        ' Tune here rather than in the player so Back can keep this session in the preview
        m.pendingWatch = { key: ch.key, program: p }
        showToast("Tuning " + channelLabel(ch) + "…")
        m.watchTask = createObject("roSGNode", "PlexTask")
        m.watchTask.config = m.top.config
        m.watchTask.action = "tuneLiveChannel"
        m.watchTask.item = { dvrId: m.ctx.dvrId, channelId: ch.tuneId, tuneAlt: ch.tuneAlt, releaseFirst: takeOwnedLive(ch.key) }
        m.watchTask.observeField("response", "onWatchTuned")
        m.watchTask.control = "RUN"
        return
    end if
    launchWatch(ch, p, url)
end sub

sub onWatchTuned()
    response = m.watchTask.response
    pending = m.pendingWatch
    m.pendingWatch = invalid
    if pending = invalid or not m.byKey.DoesExist(pending.key) then return
    if response = invalid or response.ok <> true or response.url = invalid or response.url = "" then
        err = "Could not tune this channel"
        if response <> invalid and response.error <> invalid then err = response.error
        showToast(err)
        return
    end if
    onToastDone()
    adoptLive(pending.key, response)
    launchWatch(m.byKey[pending.key], pending.program, response.url)
end sub

sub launchWatch(ch as Object, p as Dynamic, url as String)
    m.watching = { key: ch.key, url: url }
    channelName = channelLabel(ch)
    title = channelName
    shortTitle = channelName
    description = ""
    art = ""
    year = ""
    contentRating = ""
    rating = ""
    programKind = ""
    episodeLabel = ""
    cast = []
    streamFormat = "hls"
    mediaType = "livetv"
    dvrId = ""
    if m.ctx <> invalid then dvrId = m.ctx.dvrId

    if ch.source = "cable" then
        mediaType = "sport"
        streamFormat = valueOr(ch.streamFormat, "hls")
        art = valueOr(ch.logo, "")
        if valueOr(ch.summary, "") <> "" then description = ch.summary
    end if

    if p <> invalid and p.placeholder <> true then
        if valueOr(p.title, "") <> "" then
            shortTitle = valueOr(p.title, "")
            title = shortTitle + "  ·  " + channelName
        end if
        if valueOr(p.summary, "") <> "" then description = valueOr(p.summary, "")
        if valueOr(p.art, "") <> "" then art = valueOr(p.art, "")
        if valueOr(p.backdrop, "") <> "" then art = valueOr(p.backdrop, "")
        if valueOr(p.poster, "") <> "" and art = "" then art = valueOr(p.poster, "")
        year = valueOr(p.year, "")
        contentRating = valueOr(p.contentRating, "")
        rating = valueOr(p.rating, "")
        programKind = valueOr(p.kind, "")
        episodeLabel = valueOr(p.episodeLabel, "")
        if episodeLabel <> "" and description = "" then description = episodeLabel
        if p.cast <> invalid then cast = p.cast
    end if

    m.top.selectedItem = {
        title: title,
        shortTitle: shortTitle,
        description: description,
        mediaType: mediaType,
        programKind: programKind,
        ratingKey: "",
        key: valueOr(ch.key, ""),
        channelId: valueOr(ch.tuneId, ""),
        tuneAlt: valueOr(ch.tuneAlt, ""),
        dvrId: dvrId,
        streamUrl: url,
        streamFormat: streamFormat,
        hdPosterUrl: art,
        hdBackdropUrl: art,
        year: year,
        contentRating: contentRating,
        rating: rating,
        cast: cast,
        duration: 0,
        viewOffset: 0
    }
end sub

sub openProgramMenu(includeWatch as Boolean)
    ch = focusedChannel()
    p = focusedProgram()
    if ch = invalid or p = invalid then return
    actions = []
    if includeWatch then actions.push({ label: "Watch " + channelLabel(ch) + " live", act: "watch" })

    loadingRecord = false
    if ch.source = "cable" then
        actions.push({ label: "Recording not available on this channel", act: "none" })
    else
        rec = recordingFor(ch, p)
        seriesId = seriesRuleFor(p)
        if rec <> invalid and seriesId = "" then seriesId = seriesRuleIdForUpcoming(rec)
        if seriesId <> "" then
            actions.push({ label: "Edit series rule", act: "editRule", data: seriesId })
            actions.push({ label: "Delete series rule", act: "confirmDelete", data: { subscriptionId: seriesId, title: p.title, done: "Series rule deleted" } })
        end if
        if rec <> invalid and rec.subscriptionId <> seriesId then
            actions.push({ label: "Cancel recording", act: "cancel", data: { subscriptionId: rec.subscriptionId, done: "Recording cancelled" } })
        end if
        if rec = invalid and seriesId = "" and p.placeholder <> true and valueOr(p.guid, "") <> "" and p.endsAt > nowSeconds() then
            actions.push({ label: "Loading record options…", act: "none" })
            loadingRecord = true
        end if
    end if
    actions.push({ label: "Refresh guide", act: "refreshGuide" })
    actions.push({ label: "Close", act: "close" })

    subText = channelLabel(ch)
    if ch.source = "cable" then subText = subText + "  ·  Cable"
    if p.placeholder <> true then
        when = rangeText(p.beginsAt, p.endsAt)
        if dayKey(p.beginsAt) <> dayKey(nowSeconds()) then when = dayLabel(p.beginsAt) + " " + when
        subText = subText + "  ·  " + when
    end if
    openActionMenu(p.title, subText, actions)

    if loadingRecord then
        m.recordTask = createObject("roSGNode", "PlexTask")
        m.recordTask.config = m.top.config
        m.recordTask.action = "recordOptions"
        m.recordTask.item = { guid: p.guid, kind: valueOr(p.kind, "") }
        m.recordTask.observeField("response", "onRecordOptions")
        m.recordTask.control = "RUN"
    end if
end sub

sub onRecordOptions()
    if m.zone <> "menu" then return
    response = m.recordTask.response
    replaced = []
    for each action in m.menuActions
        if action.act = "none" then
            if response <> invalid and response.ok = true then
                for each opt in response.options
                    replaced.push({ label: opt.label, act: "record", data: opt })
                end for
            else
                err = "Recording unavailable"
                if response <> invalid and response.error <> invalid then err = response.error
                replaced.push({ label: err, act: "none" })
            end if
        else
            replaced.push(action)
        end if
    end for
    focusIdx = m.menuList.itemFocused
    setMenuActions(replaced)
    if focusIdx <> invalid and focusIdx >= 0 and focusIdx < replaced.count() then m.menuList.jumpToItem = focusIdx
end sub

sub openActionMenu(title as String, subText as String, actions as Object)
    m.menuReturnZone = m.zone
    m.zone = "menu"
    m.menuTitle.text = title
    m.menuSub.text = subText
    setMenuActions(actions)
    m.menu.visible = true
    m.menuList.jumpToItem = 0
    m.menuList.setFocus(true)
    if m.tab = 0 then renderGrid()
end sub

sub setMenuActions(actions as Object)
    m.menuActions = actions
    root = createObject("roSGNode", "ContentNode")
    for each action in actions
        item = root.createChild("ContentNode")
        item.title = "   " + action.label
    end for
    m.menuList.content = root
    rows = actions.count()
    if rows > 9 then rows = 9
    h = 176 + rows * 72
    y = Int((1080 - h) / 2)
    m.menuPanel.height = h
    m.menuPanel.translation = [560, y]
    m.menuAccent.translation = [560, y]
    m.menuTitle.translation = [608, y + 36]
    m.menuSub.translation = [608, y + 92]
    m.menuListY = y + 152
    m.menuList.translation = [592, m.menuListY]
end sub

sub closeActionMenu()
    m.menu.visible = false
    m.ruleEdit = invalid
    m.zone = m.menuReturnZone
    if m.zone = "list" and m.dvrItems.count() > 0 then
        m.dvrList.setFocus(true)
    else
        if m.zone = "list" then m.zone = "tabs"
        m.top.setFocus(true)
    end if
    paintTabs()
    if m.tab = 0 then
        renderGrid()
        updateGridInfo()
    end if
end sub

sub onMenuSelected()
    idx = m.menuList.itemSelected
    if idx = invalid or idx < 0 or idx >= m.menuActions.count() then return
    action = m.menuActions[idx]
    if action.act = "none" then return
    if action.act = "close" then
        closeActionMenu()
    else if action.act = "refreshGuide" then
        closeActionMenu()
        if m.cableLoading = true then
            showToast("Refresh already in progress")
        else
            showToast("Refreshing guide…")
            loadGuide()
            loadSchedule()
        end if
    else if action.act = "pickSetting" then
        openSettingPicker(action.data)
    else if action.act = "choose" then
        closeSettingPicker(action.data)
    else if action.act = "saveRule" then
        saveRule()
    else if action.act = "editRule" then
        closeActionMenu()
        editRuleById(action.data)
    else if action.act = "confirmDelete" then
        closeActionMenu()
        openActionMenu("Delete this recording rule?", valueOr(action.data.title, ""), [
            { label: "Keep rule", act: "close" },
            { label: "Delete rule", act: "cancel", data: action.data }
        ])
    else if action.act = "watch" then
        closeActionMenu()
        watchChannel(focusedChannel(), focusedProgram())
    else if action.act = "record" then
        title = m.menuTitle.text
        closeActionMenu()
        openRecordEditor(action.data, title)
    else if action.act = "createRule" then
        payload = {}
        payload.Append(m.ruleEdit.option)
        payload.overrides = m.ruleEdit.values
        closeActionMenu()
        runDvrCommand("recordCreate", payload, "Recording scheduled")
    else if action.act = "cancel" then
        closeActionMenu()
        runDvrCommand("recordCancel", action.data, valueOr(action.data.done, "Done"))
    end if
end sub

sub runDvrCommand(actionName as String, payload as Object, doneText as String)
    showToast("Working…")
    m.dvrDoneText = doneText
    m.dvrTask = createObject("roSGNode", "PlexTask")
    m.dvrTask.config = m.top.config
    m.dvrTask.action = actionName
    m.dvrTask.item = payload
    m.dvrTask.observeField("response", "onDvrCommandDone")
    m.dvrTask.control = "RUN"
end sub

sub onDvrCommandDone()
    response = m.dvrTask.response
    if response <> invalid and response.ok = true then
        showToast(m.dvrDoneText)
    else
        err = "DVR request failed"
        if response <> invalid and response.error <> invalid then err = response.error
        showToast(err)
    end if
    loadSchedule()
end sub

sub showToast(text as String)
    m.toastLabel.text = text
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToastDone()
    m.toast.visible = false
end sub

' ---------------------------------------------------------------------------
' Remote
' ---------------------------------------------------------------------------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.zone = "menu" then
        if key = "back" or key = "options" then
            if m.ruleEdit <> invalid and m.ruleEdit.picking >= 0 then
                closeSettingPicker(invalid)
            else
                closeActionMenu()
            end if
        end if
        return true
    end if

    if m.zone = "tabs" then
        if key = "left" then
            if m.tab = 0 then
                leaveToMenu()
            else
                applyTab(m.tab - 1)
            end if
            return true
        else if key = "right" then
            if m.tab < m.tabNames.count() - 1 then applyTab(m.tab + 1)
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

    if m.zone = "list" then
        ' Keys the list didn't consume (e.g. right) stop here
        return key <> "back"
    end if

    ' Guide grid
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
    else if key = "OK" then
        p = focusedProgram()
        if p = invalid then return true
        if p.placeholder = true or isOnNow(p) or p.endsAt <= nowSeconds() then
            watchChannel(focusedChannel(), p)
        else
            openProgramMenu(true)
        end if
        return true
    else if key = "options" then
        openProgramMenu(true)
        return true
    else if key = "back" then
        ' First Back while scrolled ahead → jump to now on this channel;
        ' second Back → Guide/Upcoming/Rules tabs; Back again opens the menu
        if guideScrolledFromNow() then
            jumpGuideToNow()
        else
            enterTabs()
        end if
        return true
    end if
    return false
end function

function guideScrolledFromNow() as Boolean
    now = nowSeconds()
    liveStart = floorSlot(now)
    if m.winStart > liveStart then return true
    p = focusedProgram()
    if p = invalid then return false
    if p.placeholder = true then return false
    if isOnNow(p) then return false
    if p.endsAt <= now then return true
    if p.lb > now then return true
    return false
end function

sub jumpGuideToNow()
    now = nowSeconds()
    m.minWin = floorSlot(now)
    m.winStart = m.minWin
    refocusAnchor(now)
    renderGrid()
    updateGridInfo()
end sub

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
