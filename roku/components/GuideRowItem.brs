sub init()
    m.bg = m.top.findNode("bg")
    m.focusBar = m.top.findNode("focusBar")
    m.col0 = m.top.findNode("col0")
    m.col1 = m.top.findNode("col1")
    m.col2 = m.top.findNode("col2")
    m.col3 = m.top.findNode("col3")
    m.itemWidth = 1776
    m.itemHeight = 84
end sub

sub onSizeChange()
    if m.top.width > 0 then m.itemWidth = m.top.width
    if m.top.height > 0 then m.itemHeight = m.top.height
    if m.bg <> invalid then
        m.bg.width = m.itemWidth
        m.bg.height = m.itemHeight
    end if
    if m.focusBar <> invalid then m.focusBar.height = m.itemHeight
    cy = Int((m.itemHeight - 52) / 2)
    if cy < 0 then cy = 0
    if m.col0 <> invalid then m.col0.translation = [24, cy]
    if m.col1 <> invalid then m.col1.translation = [340, cy]
    if m.col2 <> invalid then m.col2.translation = [980, cy]
    if m.col3 <> invalid then m.col3.translation = [1260, cy]
end sub

sub onContentChange()
    item = m.top.itemContent
    if item = invalid then return
    if m.col0 <> invalid then m.col0.text = fieldStr(item, "col0")
    if m.col1 <> invalid then m.col1.text = fieldStr(item, "col1")
    if m.col2 <> invalid then m.col2.text = fieldStr(item, "col2")
    if m.col3 <> invalid then m.col3.text = fieldStr(item, "col3")
    ' Sports rows leave the time column blank, so the event title gets its room
    if m.col1 <> invalid and m.col2 <> invalid then
        if m.col2.text = "" then m.col1.width = 900 else m.col1.width = 620
    end if
    ' DVR rules put the show in the first column and leave the second empty
    if m.col0 <> invalid and m.col1 <> invalid then
        if m.col1.text = "" then m.col0.width = 940 else m.col0.width = 300
    end if
end sub

function fieldStr(item as Object, name as String) as String
    if item = invalid then return ""
    v = invalid
    if name = "col0" and item.DoesExist("col0") then v = item.col0
    if name = "col1" and item.DoesExist("col1") then v = item.col1
    if name = "col2" and item.DoesExist("col2") then v = item.col2
    if name = "col3" and item.DoesExist("col3") then v = item.col3
    if v = invalid then
        if name = "col1" and item.title <> invalid then return item.title
        return ""
    end if
    if type(v) = "String" or type(v) = "roString" then return v
    return ""
end function

sub onFocusPercentChange()
    refreshFocusVisual()
end sub

sub onOwnerFocusChange()
    refreshFocusVisual()
end sub

sub refreshFocusVisual()
    fp = m.top.focusPercent
    if fp = invalid then fp = 0
    focused = fp > 0.5 and m.top.listHasFocus <> false
    if m.bg <> invalid then
        if focused then
            m.bg.opacity = 0.85
            m.bg.color = "0x2A3650"
        else
            m.bg.opacity = 0.0
        end if
    end if
    if m.focusBar <> invalid then m.focusBar.visible = focused
    if focused then
        if m.col0 <> invalid then m.col0.color = "0xFFFFFF"
        if m.col1 <> invalid then m.col1.color = "0xFFFFFF"
        if m.col2 <> invalid then m.col2.color = "0xD0D8E8"
        if m.col3 <> invalid then m.col3.color = "0xFFFFFF"
    else
        if m.col0 <> invalid then m.col0.color = "0xA8B0C0"
        if m.col1 <> invalid then m.col1.color = "0xE8EEF8"
        if m.col2 <> invalid then m.col2.color = "0x8FA0B8"
        if m.col3 <> invalid then m.col3.color = "0xC5CCD8"
    end if
end sub
