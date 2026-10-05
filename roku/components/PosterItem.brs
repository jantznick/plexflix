sub init()
    m.poster = m.top.findNode("poster")
    m.focusTop = m.top.findNode("focusTop")
    m.focusBottom = m.top.findNode("focusBottom")
    m.focusLeft = m.top.findNode("focusLeft")
    m.focusRight = m.top.findNode("focusRight")
    m.focusAccent = m.top.findNode("focusAccent")
    m.progressBg = m.top.findNode("progressBg")
    m.progressFg = m.top.findNode("progressFg")
    m.itemWidth = 148
    m.itemHeight = 222
    setFocused(false)
end sub

sub onSizeChange()
    if m.top.width > 0 then m.itemWidth = m.top.width
    if m.top.height > 0 then m.itemHeight = m.top.height

    m.poster.width = m.itemWidth
    m.poster.height = m.itemHeight

    m.focusTop.width = m.itemWidth + 8
    m.focusBottom.width = m.itemWidth + 8
    m.focusBottom.translation = [-4, m.itemHeight]
    m.focusLeft.height = m.itemHeight + 8
    m.focusRight.height = m.itemHeight + 8
    m.focusRight.translation = [m.itemWidth, -4]
    m.focusAccent.width = m.itemWidth + 8
    m.focusAccent.translation = [-4, m.itemHeight]

    m.progressBg.width = m.itemWidth
    m.progressBg.translation = [0, m.itemHeight - 5]
    m.progressFg.translation = [0, m.itemHeight - 5]
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
    setFocused(m.top.focusPercent > 0.5)
end sub

sub setFocused(focused as Boolean)
    m.focusTop.visible = focused
    m.focusBottom.visible = focused
    m.focusLeft.visible = focused
    m.focusRight.visible = focused
    m.focusAccent.visible = focused
    if focused then
        m.poster.opacity = 1.0
    else
        m.poster.opacity = 0.72
    end if
end sub
