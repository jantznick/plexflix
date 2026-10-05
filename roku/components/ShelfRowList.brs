function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    info = m.top.rowItemFocused

    if key = "up" then
        if info <> invalid and info.count() > 0 and info[0] = 0 then
            m.top.escapeUp = true
            return true
        end if
    else if key = "left" then
        if info <> invalid and info.count() > 1 and info[1] = 0 then
            m.top.escapeLeft = true
            return true
        end if
    else if key = "back" then
        m.top.escapeBack = true
        return true
    end if

    return false
end function
