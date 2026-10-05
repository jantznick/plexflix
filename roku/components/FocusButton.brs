sub init()
    m.bg = m.top.findNode("bg")
    m.label = m.top.findNode("label")
    ' focusedChild changes whenever focus enters or leaves this node
    m.top.observeField("focusedChild", "onPaint")
    onSizeChange()
    onTextChange()
end sub

sub onSizeChange()
    if m.bg = invalid then return
    w = m.top.buttonWidth
    h = m.top.buttonHeight
    if w <= 0 then w = 200
    if h <= 0 then h = 48
    m.bg.width = w
    m.bg.height = h
    m.label.width = w
    m.label.height = h
end sub

sub onTextChange()
    if m.label = invalid then return
    size = m.top.fontSize
    if size <= 0 then size = 22
    m.label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", Int(size))
    m.label.text = m.top.text
    onPaint()
end sub

sub onPaint()
    if m.bg = invalid then return
    if m.top.hasFocus() then
        m.bg.color = "0xFFFFFF"
        m.label.color = "0x111118"
    else if m.top.accent = true then
        m.bg.color = "0xE50914"
        m.label.color = "0xFFFFFF"
    else
        m.bg.color = "0x2A2A32"
        m.label.color = "0xFFFFFF"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "OK" or key = "play" then
        m.top.selected = true
        return true
    end if
    ' Everything else belongs to the screen that owns the button row
    return false
end function
