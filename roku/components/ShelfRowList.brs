function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    info = m.top.rowItemFocused
    rowIndex = 0
    colIndex = 0
    if info <> invalid and info.count() > 0 then rowIndex = info[0]
    if info <> invalid and info.count() > 1 then colIndex = info[1]

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
    else if key = "back" then
        m.top.escapeBack = true
        return true
    end if

    return false
end function
