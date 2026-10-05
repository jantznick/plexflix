sub init()
    m.still = m.top.findNode("still")
    m.titleLabel = m.top.findNode("titleLabel")
    m.titleScrim = m.top.findNode("titleScrim")
    m.shadow = m.top.findNode("shadow")
    m.focusGlow = m.top.findNode("focusGlow")
    m.focusRing = m.top.findNode("focusRing")
    m.focusAccent = m.top.findNode("focusAccent")
    m.ringT = m.top.findNode("ringT")
    m.ringB = m.top.findNode("ringB")
    m.ringL = m.top.findNode("ringL")
    m.ringR = m.top.findNode("ringR")
    m.progressBg = m.top.findNode("progressBg")
    m.progressFg = m.top.findNode("progressFg")
    m.itemWidth = 320
    m.itemHeight = 180
    setFocused(false)
end sub

sub onSizeChange()
    if m.top.width > 0 then m.itemWidth = m.top.width
    if m.top.height > 0 then m.itemHeight = m.top.height

    m.still.width = m.itemWidth
    m.still.height = m.itemHeight
    m.titleScrim.width = m.itemWidth
    m.titleScrim.translation = [0, m.itemHeight - 52]
    m.titleLabel.width = m.itemWidth - 24
    m.titleLabel.translation = [12, m.itemHeight - 44]

    if m.shadow <> invalid then
        m.shadow.width = m.itemWidth + 16
        m.shadow.height = m.itemHeight + 12
        m.shadow.translation = [10, 10]
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
    if m.ringT <> invalid then
        m.ringT.width = ringW
        m.ringT.height = 4
        m.ringT.translation = [-pad, -pad]
    end if
    if m.ringB <> invalid then
        m.ringB.width = ringW
        m.ringB.height = 4
        m.ringB.translation = [-pad, m.itemHeight + pad - 4]
    end if
    if m.ringL <> invalid then
        m.ringL.width = 4
        m.ringL.height = ringH
        m.ringL.translation = [-pad, -pad]
    end if
    if m.ringR <> invalid then
        m.ringR.width = 4
        m.ringR.height = ringH
        m.ringR.translation = [m.itemWidth + pad - 4, -pad]
    end if

    m.progressBg.width = m.itemWidth
    m.progressBg.translation = [0, m.itemHeight - 4]
    m.progressFg.translation = [0, m.itemHeight - 4]
    refreshProgress()
end sub

sub onContentChange()
    item = m.top.itemContent
    if item = invalid then return

    if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
        m.still.uri = item.hdPosterUrl
    else
        m.still.uri = "pkg:/images/poster_placeholder.png"
    end if

    label = ""
    if item.title <> invalid then label = item.title
    m.titleLabel.text = label
    refreshProgress()
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
    fp = m.top.focusPercent
    if fp = invalid then fp = 0
    setFocused(fp > 0.5)
end sub

sub setFocused(focused as Boolean)
    if m.focusGlow <> invalid then m.focusGlow.visible = focused
    if m.focusRing <> invalid then m.focusRing.visible = focused
    if m.focusAccent <> invalid then m.focusAccent.visible = focused
    if m.ringT <> invalid then m.ringT.visible = focused
    if m.ringB <> invalid then m.ringB.visible = focused
    if m.ringL <> invalid then m.ringL.visible = focused
    if m.ringR <> invalid then m.ringR.visible = focused
    if focused then
        m.still.opacity = 1.0
        if m.shadow <> invalid then
            m.shadow.opacity = 0.7
            m.shadow.translation = [14, 14]
        end if
    else
        m.still.opacity = 0.78
        if m.shadow <> invalid then
            m.shadow.opacity = 0.4
            m.shadow.translation = [10, 10]
        end if
    end if
end sub
