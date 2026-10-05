sub init()
    m.top.functionName = "runKeyboard"
end sub

sub runKeyboard()
    m.top.cancelled = true
    m.top.result = ""

    ' roKeyboardScreen is legacy / missing in brs-desktop — fail soft
    keyboard = CreateObject("roKeyboardScreen")
    if keyboard = invalid then
        m.top.cancelled = true
        m.top.result = ""
        return
    end if

    port = CreateObject("roMessagePort")
    keyboard.SetMessagePort(port)
    title = "Search library"
    if m.top.prompt <> invalid and m.top.prompt <> "" then title = m.top.prompt
    keyboard.SetTitle(title)
    if m.top.initialText <> invalid and m.top.initialText <> "" then
        keyboard.SetText(m.top.initialText)
    end if
    keyboard.SetDisplayText("Title")
    keyboard.Show()

    while true
        msg = wait(0, port)
        if msg = invalid then exit while
        if type(msg) = "roKeyboardScreenEvent" then
            if msg.IsScreenClosed() then
                if msg.IsButtonPressed() then
                    m.top.result = keyboard.GetText()
                    m.top.cancelled = false
                end if
                exit while
            end if
        end if
    end while
end sub
