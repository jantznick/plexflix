sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    scene = screen.CreateScene("MainScene")
    scene.observeField("exitApp", port)
    screen.Show()

    while true
        msg = wait(0, port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.IsScreenClosed() then return
        else if msgType = "roSGNodeEvent"
            if msg.getField() = "exitApp" and msg.getData() = true then
                screen.Close()
                return
            end if
        end if
    end while
end sub