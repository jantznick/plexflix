function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    cols = m.top.numColumns
    if cols = invalid or cols < 1 then cols = 1

    idx = m.top.itemFocused
    if idx = invalid then idx = 0

    if key = "up" then
        ' Top row → let the screen reclaim focus (Search / Clear / filters)
        if idx < cols then
            m.top.escapeUp = true
            return true
        end if
    else if key = "back" then
        m.top.escapeBack = true
        return true
    end if
    return false
end function
