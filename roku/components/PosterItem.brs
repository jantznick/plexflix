sub init()
    m.visual = m.top.findNode("visual")
    m.poster = m.top.findNode("poster")
    m.shadow = m.top.findNode("shadow")
    m.cardBg = m.top.findNode("cardBg")
    m.focusChrome = m.top.findNode("focusChrome")
    m.focusAccent = m.top.findNode("focusAccent")
    m.ringT = m.top.findNode("ringT")
    m.ringB = m.top.findNode("ringB")
    m.ringL = m.top.findNode("ringL")
    m.ringR = m.top.findNode("ringR")
    m.progressBg = m.top.findNode("progressBg")
    m.progressFg = m.top.findNode("progressFg")
    m.watchedBadge = m.top.findNode("watchedBadge")
    m.unwatchedPill = m.top.findNode("unwatchedPill")
    m.unwatchedLabel = m.top.findNode("unwatchedLabel")
    m.titleBar = m.top.findNode("titleBar")
    m.titleLabel = m.top.findNode("titleLabel")
    m.itemWidth = 168
    m.itemHeight = 252
    m.focusPad = 8
    m.ringThick = 4
    setFocused(false)
    if m.visual <> invalid then m.visual.translation = [0, 0]
end sub

sub onRowIndexChange()
end sub

sub onSizeChange()
    if m.top.width > 0 then m.itemWidth = m.top.width
    if m.top.height > 0 then m.itemHeight = m.top.height

    pad = m.focusPad
    thick = m.ringThick
    contentW = m.itemWidth - pad * 2
    contentH = m.itemHeight - pad * 2
    if contentW < 40 then contentW = 40
    if contentH < 40 then contentH = 40

    m.poster.width = contentW
    m.poster.height = contentH
    m.poster.translation = [pad, pad]
    if m.cardBg <> invalid then
        m.cardBg.width = contentW
        m.cardBg.height = contentH
        m.cardBg.translation = [pad, pad]
    end if
    if m.shadow <> invalid then
        m.shadow.width = contentW
        m.shadow.height = contentH
        m.shadow.translation = [pad + 6, pad + 6]
    end if

    ' Ring sits on the cell edge — fully inside RowList/MarkupGrid clip bounds
    if m.ringT <> invalid then
        m.ringT.width = m.itemWidth
        m.ringT.height = thick
        m.ringT.translation = [0, 0]
    end if
    if m.ringB <> invalid then
        m.ringB.width = m.itemWidth
        m.ringB.height = thick
        m.ringB.translation = [0, m.itemHeight - thick]
    end if
    if m.ringL <> invalid then
        m.ringL.width = thick
        m.ringL.height = m.itemHeight
        m.ringL.translation = [0, 0]
    end if
    if m.ringR <> invalid then
        m.ringR.width = thick
        m.ringR.height = m.itemHeight
        m.ringR.translation = [m.itemWidth - thick, 0]
    end if
    if m.focusAccent <> invalid then
        m.focusAccent.width = m.itemWidth - thick * 2
        m.focusAccent.height = thick
        m.focusAccent.translation = [thick, m.itemHeight - thick * 2]
    end if

    barHeight = progressBarHeight()
    m.progressBg.width = contentW
    m.progressBg.height = barHeight
    m.progressFg.height = barHeight
    m.progressBg.translation = [pad, pad + contentH - barHeight]
    m.progressFg.translation = [pad, pad + contentH - barHeight]
    layoutBadges()
    if m.titleBar <> invalid then
        m.titleBar.width = contentW
        m.titleBar.translation = [pad, pad + contentH - 56]
    end if
    if m.titleLabel <> invalid then
        m.titleLabel.width = contentW - 8
        m.titleLabel.translation = [pad + 4, pad + contentH - 52]
    end if
    refreshProgress()
end sub

function progressBarHeight() as Integer
    ' Scales with the tile so the bar stays visible on a 7-wide grid without
    ' swamping the small Continue Watching posters
    height = Int(m.itemWidth / 26)
    if height < 6 then height = 6
    if height > 12 then height = 12
    return height
end function

sub layoutBadges()
    if m.watchedBadge = invalid then return

    pad = m.focusPad
    contentW = m.itemWidth - pad * 2

    size = Int(contentW / 6)
    if size < 26 then size = 26
    if size > 46 then size = 46
    badgePad = Int(size / 4)

    m.watchedBadge.width = size
    m.watchedBadge.height = size
    m.watchedBadge.translation = [pad + contentW - size - badgePad, pad + badgePad]

    pillHeight = Int(size * 0.78)
    digits = 1
    if m.unwatchedLabel <> invalid and Len(m.unwatchedLabel.text) > 1 then
        digits = Len(m.unwatchedLabel.text)
    end if
    pillWidth = size + (digits - 1) * Int(size / 3)

    m.unwatchedPill.width = pillWidth
    m.unwatchedPill.height = pillHeight
    m.unwatchedPill.translation = [pad + contentW - pillWidth - badgePad, pad + badgePad]
    if m.unwatchedLabel <> invalid then
        m.unwatchedLabel.width = pillWidth
        m.unwatchedLabel.height = pillHeight
        m.unwatchedLabel.translation = [pad + contentW - pillWidth - badgePad, pad + badgePad]
    end if
end sub

sub onContentChange()
    item = m.top.itemContent
    if item = invalid then return

    if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
        m.poster.uri = item.hdPosterUrl
    else
        m.poster.uri = "pkg:/images/poster_placeholder.png"
    end if

    refreshTitle()
    refreshProgress()
    refreshWatchedState()
end sub

sub refreshTitle()
    item = m.top.itemContent
    if item = invalid or m.titleLabel = invalid then return
    label = ""
    if item.shortTitle <> invalid and asString(item.shortTitle) <> "" then
        label = asString(item.shortTitle)
    else if item.title <> invalid then
        label = asString(item.title)
    end if
    if label = "" then return
    if Len(label) > 42 then label = Left(label, 40) + "…"
    m.titleLabel.text = label
end sub

sub refreshProgress()
    item = m.top.itemContent
    if item = invalid then
        m.progressBg.visible = false
        m.progressFg.visible = false
        return
    end if

    duration = 0
    offset = 0
    if item.duration <> invalid then duration = item.duration
    if item.viewOffset <> invalid then offset = item.viewOffset

    if duration > 0 and offset > 0 then
        pct = offset / duration
        if pct > 1 then pct = 1
        contentW = m.itemWidth - m.focusPad * 2
        m.progressBg.visible = true
        m.progressFg.visible = true
        m.progressFg.width = contentW * pct
    else
        m.progressBg.visible = false
        m.progressFg.visible = false
    end if
end sub

sub refreshWatchedState()
    if m.watchedBadge = invalid then return

    item = m.top.itemContent
    watched = false
    unwatched = 0
    if item <> invalid then
        if item.watched = true then watched = true
        if item.unwatchedCount <> invalid then unwatched = item.unwatchedCount
    end if

    showPill = (not watched and unwatched > 0)
    if showPill then
        label = asNumberString(unwatched)
        if unwatched > 99 then label = "99+"
        m.unwatchedLabel.text = label
        layoutBadges()
    end if

    m.watchedBadge.visible = watched
    m.unwatchedPill.visible = showPill
    m.unwatchedLabel.visible = showPill
end sub

sub onFocusPercentChange()
    refreshFocusVisual()
end sub

sub onOwnerFocusChange()
    refreshFocusVisual()
end sub

sub refreshFocusVisual()
    fp = m.top.focusPercent
    if fp = invalid then fp = 0
    setFocused(fp > 0.5 and ownerHasFocus())
end sub

function ownerHasFocus() as Boolean
    ' A grid keeps focusPercent on its selected item even when the remote has
    ' moved on to a toolbar or the sidebar, so the ring has to follow the owner
    if m.top.gridHasFocus = false then return false
    if m.top.rowListHasFocus = false then return false
    if m.top.rowHasFocus = false then return false
    return true
end function

sub setFocused(focused as Boolean)
    if m.focusChrome <> invalid then m.focusChrome.visible = focused
    if m.titleBar <> invalid then m.titleBar.visible = focused
    if m.titleLabel <> invalid then m.titleLabel.visible = focused
    if focused then
        refreshTitle()
        m.poster.opacity = 1.0
        if m.shadow <> invalid then
            m.shadow.opacity = 0.7
            m.shadow.translation = [m.focusPad + 8, m.focusPad + 8]
        end if
    else
        m.poster.opacity = 0.78
        if m.shadow <> invalid then
            m.shadow.opacity = 0.4
            m.shadow.translation = [m.focusPad + 6, m.focusPad + 6]
        end if
    end if
end sub

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return ""
end function

function asNumberString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        return StrI(Int(value)).Trim()
    end if
    return ""
end function
