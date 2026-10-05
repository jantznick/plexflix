sub init()
    m.rail = m.top.findNode("rail")
    m.rows = m.top.findNode("rows")
    m.rowHeight = 34
    m.railWidth = 56
    m.items = []
    m.index = 0
    m.top.observeField("focusedChild", "paint")
end sub

sub onLettersChange()
    if m.rows = invalid then return
    letters = m.top.letters
    if letters = invalid then letters = []

    while m.rows.getChildCount() > 0
        m.rows.removeChildIndex(0)
    end while
    m.items = []

    y = 0
    for each entry in letters
        letter = ""
        enabled = true
        if entry <> invalid then
            if entry.letter <> invalid then letter = entry.letter
            if entry.enabled = false then enabled = false
        end if
        if letter <> "" then
            label = createObject("roSGNode", "Label")
            label.width = m.railWidth
            label.height = m.rowHeight
            label.horizAlign = "center"
            label.vertAlign = "center"
            label.text = letter
            label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 20)
            label.translation = [0, y]
            m.rows.appendChild(label)
            m.items.push({ letter: letter, enabled: enabled, label: label })
            y = y + m.rowHeight
        end if
    end for

    m.rail.height = y + 12
    if m.index > m.items.count() - 1 then m.index = 0
    if m.items.count() > 0 and m.items[m.index].enabled <> true then m.index = nextEnabled(0, 1)
    paint()
end sub

sub paint()
    focused = m.top.hasFocus()
    for i = 0 to m.items.count() - 1
        entry = m.items[i]
        if i = m.index and focused then
            entry.label.color = "0xFFFFFF"
        else if entry.enabled = true then
            entry.label.color = "0x9A9AA4"
        else
            entry.label.color = "0x44444C"
        end if
    end for
end sub

function nextEnabled(from as Integer, delta as Integer) as Integer
    i = from
    while i >= 0 and i <= m.items.count() - 1
        if m.items[i].enabled = true then return i
        i = i + delta
    end while
    return m.index
end function

sub moveBy(delta as Integer)
    if m.items.count() = 0 then return
    target = nextEnabled(m.index + delta, delta)
    if target < 0 or target > m.items.count() - 1 then return
    if m.items[target].enabled <> true then return
    m.index = target
    paint()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up" then
        moveBy(-1)
        return true
    else if key = "down" then
        moveBy(1)
        return true
    else if key = "OK" or key = "play" then
        if m.items.count() > 0 then m.top.letterSelected = m.items[m.index].letter
        return true
    else if key = "left" then
        m.top.escapeLeft = true
        return true
    end if
    return false
end function
