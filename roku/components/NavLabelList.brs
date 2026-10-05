function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    focused = m.top.itemFocused
    count = 0
    if m.top.content <> invalid then count = m.top.content.getChildCount()

    ' Prevent wrap-around cycling
    if key = "up" and focused = 0 then
        return true
    else if key = "down" and count > 0 and focused >= count - 1 then
        return true
    end if

    return false
end function
