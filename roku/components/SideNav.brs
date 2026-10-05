sub init()
    m.homeBg = m.top.findNode("homeBg")
    m.playlistsBg = m.top.findNode("playlistsBg")
    m.sportsBg = m.top.findNode("sportsBg")
    m.index = 0
    m.ids = ["home", "playlists", "sports"]
    paint()
end sub

sub onActiveChange()
    active = m.top.active
    if active = "home" then
        m.index = 0
    else if active = "playlists" then
        m.index = 1
    else if active = "sports" then
        m.index = 2
    end if
    paint()
end sub

sub paint()
    m.homeBg.color = "0x1A1A1E"
    m.playlistsBg.color = "0x1A1A1E"
    m.sportsBg.color = "0x1A1A1E"
    if m.index = 0 then
        m.homeBg.color = "0xE50914"
    else if m.index = 1 then
        m.playlistsBg.color = "0xE50914"
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
        ' Let parent move focus into content
        return false
    end if
    return false
end function
