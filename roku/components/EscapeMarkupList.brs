function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    idx = m.top.itemFocused
    if idx = invalid then idx = 0

    if key = "up" then
        if idx <= 0 then
            m.top.escapeUp = true
            return true
        end if
    else if key = "left" then
        m.top.escapeLeft = true
        return true
    else if key = "back" then
        m.top.escapeBack = true
        return true
    else if key = "options" then
        m.top.escapeOptions = true
        return true
    end if
    return false
end function
