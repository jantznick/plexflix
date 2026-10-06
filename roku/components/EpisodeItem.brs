sub init()
    m.still = m.top.findNode("still")
    m.titleLabel = m.top.findNode("titleLabel")
    m.titleScrim = m.top.findNode("titleScrim")
    m.shadow = m.top.findNode("shadow")
    m.progressBg = m.top.findNode("progressBg")
    m.progressFg = m.top.findNode("progressFg")
    m.watchedBadge = m.top.findNode("watchedBadge")
    m.itemWidth = 320
    m.itemHeight = 180
    m.focusPad = 8
    setFocused(false)
end sub

sub onSizeChange()
    if m.top.width > 0 then m.itemWidth = m.top.width
    if m.top.height > 0 then m.itemHeight = m.top.height

    pad = m.focusPad
    contentW = m.itemWidth - pad * 2
    contentH = m.itemHeight - pad * 2
    if contentW < 40 then contentW = 40
    if contentH < 40 then contentH = 40

    m.still.width = contentW
    m.still.height = contentH
    m.still.translation = [pad, pad]
    m.titleScrim.width = contentW
    m.titleScrim.translation = [pad, pad + contentH - 52]
    m.titleLabel.width = contentW - 24
    m.titleLabel.translation = [pad + 12, pad + contentH - 44]

    if m.shadow <> invalid then
        m.shadow.width = contentW
        m.shadow.height = contentH
        m.shadow.translation = [pad + 6, pad + 6]
    end if

    barHeight = 8
    m.progressBg.width = contentW
    m.progressBg.translation = [pad, pad + contentH - barHeight]
    m.progressFg.translation = [pad, pad + contentH - barHeight]

    if m.watchedBadge <> invalid then
        badge = 34
        m.watchedBadge.translation = [pad + contentW - badge - 8, pad + 8]
    end if
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
    if m.watchedBadge <> invalid then m.watchedBadge.visible = (item.watched = true)
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

sub onFocusPercentChange()
    refreshFocusVisual()
end sub

sub onOwnerFocusChange()
    refreshFocusVisual()
end sub

sub refreshFocusVisual()
    fp = m.top.focusPercent
    if fp = invalid then fp = 0
    setFocused(fp > 0.5 and m.top.rowListHasFocus <> false and m.top.rowHasFocus <> false)
end sub

sub setFocused(focused as Boolean)
    if focused then
        m.still.opacity = 1.0
        if m.shadow <> invalid then
            m.shadow.opacity = 0.7
            m.shadow.translation = [m.focusPad + 8, m.focusPad + 8]
        end if
    else
        m.still.opacity = 0.78
        if m.shadow <> invalid then
            m.shadow.opacity = 0.4
            m.shadow.translation = [m.focusPad + 6, m.focusPad + 6]
        end if
    end if
end sub
