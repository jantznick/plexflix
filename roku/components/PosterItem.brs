sub init()
    m.poster = m.top.findNode("poster")
    m.progressBg = m.top.findNode("progressBg")
    m.progressFg = m.top.findNode("progressFg")
    m.itemWidth = 148
    m.itemHeight = 222
end sub

sub onSizeChange()
    if m.top.width > 0 then m.itemWidth = m.top.width
    if m.top.height > 0 then m.itemHeight = m.top.height
    m.poster.width = m.itemWidth
    m.poster.height = m.itemHeight
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
    ' Keep MVP simple — RowList focus bitmap handles the chrome.
end sub
