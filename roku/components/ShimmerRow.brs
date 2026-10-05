sub init()
    m.bars = []
    for i = 0 to 7
        m.bars.push(m.top.findNode("bar" + StrI(i).Trim()))
    end for
    m.phase = 0
    m.timer = createObject("roSGNode", "Timer")
    m.timer.repeat = true
    m.timer.duration = 0.08
    m.timer.observeField("fire", "onTick")
    if m.top.active = true then m.timer.control = "start"
end sub

sub onActiveChange()
    if m.top.active = true then
        m.top.visible = true
        m.timer.control = "start"
    else
        m.timer.control = "stop"
        m.top.visible = false
    end if
end sub

sub onTick()
    m.phase = m.phase + 1
    for i = 0 to m.bars.count() - 1
        bar = m.bars[i]
        if bar <> invalid then
            wave = ((m.phase + i * 3) MOD 20) / 20.0
            ' Pulse between 0.35 and 0.95
            bar.opacity = 0.35 + (0.6 * Abs(wave - 0.5) * 2)
        end if
    end for
end sub
