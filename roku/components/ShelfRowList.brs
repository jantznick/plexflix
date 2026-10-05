function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    info = m.top.rowItemFocused
    rowIndex = 0
    colIndex = 0
    if info <> invalid and info.count() > 0 then rowIndex = info[0]
    if info <> invalid and info.count() > 1 then colIndex = info[1]

    row = invalid
    colCount = 0
    if m.top.content <> invalid then row = m.top.content.getChild(rowIndex)
    if row <> invalid then colCount = row.getChildCount()

    if key = "up" then
        if rowIndex = 0 then
            m.top.escapeUp = true
            return true
        end if
    else if key = "left" then
        if colIndex = 0 then
            m.top.escapeLeft = true
            return true
        end if
    else if key = "right" then
        ' Loop: wrap from last poster back to the first in this shelf
        if colCount > 1 and colIndex >= colCount - 1 then
            m.top.jumpToRowItem = [rowIndex, 0]
            return true
        end if
    else if key = "back" then
        m.top.escapeBack = true
        return true
    end if

    return false
end function
