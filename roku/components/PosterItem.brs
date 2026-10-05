sub init()
    m.poster = m.top.findNode("poster")
    m.shadow = m.top.findNode("shadow")
    m.cardBg = m.top.findNode("cardBg")
    m.focusGlow = m.top.findNode("focusGlow")
    m.focusRing = m.top.findNode("focusRing")
    m.focusAccent = m.top.findNode("focusAccent")
    m.progressBg = m.top.findNode("progressBg")
    m.progressFg = m.top.findNode("progressFg")
    m.titleBar = m.top.findNode("titleBar")
    m.titleLabel = m.top.findNode("titleLabel")
    m.itemWidth = 168
    m.itemHeight = 252
    setFocused(false)
end sub

sub onSizeChange()
    if m.top.width > 0 then m.itemWidth = m.top.width
    if m.top.height > 0 then m.itemHeight = m.top.height

    m.poster.width = m.itemWidth
    m.poster.height = m.itemHeight
    if m.cardBg <> invalid then
        m.cardBg.width = m.itemWidth
        m.cardBg.height = m.itemHeight
    end if
    if m.shadow <> invalid then
        m.shadow.width = m.itemWidth + 16
        m.shadow.height = m.itemHeight + 12
        m.shadow.translation = [10, 12]
    end if

    pad = 8
    ringW = m.itemWidth + pad * 2
    ringH = m.itemHeight + pad * 2
    if m.focusGlow <> invalid then
        m.focusGlow.width = ringW
        m.focusGlow.height = ringH
        m.focusGlow.translation = [-pad, -pad]
    end if
    if m.focusRing <> invalid then
        m.focusRing.width = ringW
        m.focusRing.height = ringH
        m.focusRing.translation = [-pad, -pad]
    end if
    if m.focusAccent <> invalid then
        m.focusAccent.width = ringW
        m.focusAccent.translation = [-pad, m.itemHeight]
    end if

    m.progressBg.width = m.itemWidth
    m.progressBg.translation = [0, m.itemHeight - 5]
    m.progressFg.translation = [0, m.itemHeight - 5]
    if m.titleBar <> invalid then
        m.titleBar.width = m.itemWidth
        m.titleBar.translation = [0, m.itemHeight - 56]
    end if
    if m.titleLabel <> invalid then
        m.titleLabel.width = m.itemWidth - 8
        m.titleLabel.translation = [4, m.itemHeight - 52]
    end if
    refreshProgress()
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
        m.progressBg.visible = true
        m.progressFg.visible = true
        m.progressFg.width = m.itemWidth * pct
    else
        m.progressBg.visible = false
        m.progressFg.visible = false
    end if
end sub

sub onFocusPercentChange()
    setFocused(m.top.focusPercent > 0.5)
end sub

sub setFocused(focused as Boolean)
    if m.focusGlow <> invalid then m.focusGlow.visible = focused
    if m.focusRing <> invalid then m.focusRing.visible = focused
    if m.focusAccent <> invalid then m.focusAccent.visible = focused
    if m.titleBar <> invalid then m.titleBar.visible = focused
    if m.titleLabel <> invalid then m.titleLabel.visible = focused
    if focused then
        refreshTitle()
        m.poster.opacity = 1.0
        if m.shadow <> invalid then
            m.shadow.opacity = 0.7
            m.shadow.translation = [14, 16]
        end if
    else
        m.poster.opacity = 0.78
        if m.shadow <> invalid then
            m.shadow.opacity = 0.4
            m.shadow.translation = [10, 12]
        end if
    end if
end sub

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return ""
end function
