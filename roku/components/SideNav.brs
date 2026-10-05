sub init()
    m.rail = m.top.findNode("rail")
    m.homeBg = m.top.findNode("homeBg")
    m.sourcesBg = m.top.findNode("sourcesBg")
    m.sportsBg = m.top.findNode("sportsBg")
    m.index = 0
    m.ids = ["home", "sources", "sports"]
    paint()
    applyExpanded()
end sub

sub onExpandedChange()
    applyExpanded()
end sub

sub applyExpanded()
    if m.top.expanded = true then
        m.top.visible = true
        m.top.translation = [0, 0]
    else
        m.top.translation = [-260, 0]
        m.top.visible = false
    end if
end sub

sub onActiveChange()
    active = m.top.active
    if active = "home" then
        m.index = 0
    else if active = "sources" then
        m.index = 1
    else if active = "sports" then
        m.index = 2
    end if
    paint()
end sub

sub paint()
    m.homeBg.color = "0x1E1E24"
    m.sourcesBg.color = "0x1E1E24"
    m.sportsBg.color = "0x1E1E24"
    if m.index = 0 then
        m.homeBg.color = "0xE50914"
    else if m.index = 1 then
        m.sourcesBg.color = "0xE50914"
    else
        m.sportsBg.color = "0xE50914"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up"
        if m.index > 0 then
            m.index = m.index - 1
            paint()
        end if
        return true
    else if key = "down"
        if m.index < m.ids.count() - 1 then
            m.index = m.index + 1
            paint()
        end if
        return true
    else if key = "OK" or key = "play"
        m.top.selected = m.ids[m.index]
        m.top.active = m.ids[m.index]
        return true
    else if key = "right"
        return false
    else if key = "back"
        m.top.expanded = false
        return true
    end if
    return false
end function
