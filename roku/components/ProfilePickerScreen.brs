sub init()
    m.profileRow = m.top.findNode("profileRow")
    m.pinOverlay = m.top.findNode("pinOverlay")
    m.pinTitle = m.top.findNode("pinTitle")
    m.pinSub = m.top.findNode("pinSub")
    m.pinDigits = m.top.findNode("pinDigits")
    m.pinError = m.top.findNode("pinError")
    m.brand = m.top.findNode("brand")
    m.headline = m.top.findNode("headline")
    m.tagline = m.top.findNode("tagline")

    m.profiles = GetProfiles()
    m.index = 0
    m.tiles = []
    m.pinMode = false
    m.pinValue = ""
    m.pinTarget = invalid
    m.pinSlots = []

    buildTiles()
    buildPinDigits()
    paintTiles()
    m.top.setFocus(true)

    m.brand.opacity = 0
    m.headline.opacity = 0
    m.tagline.opacity = 0
    m.profileRow.opacity = 0
    m.enterTimer = createObject("roSGNode", "Timer")
    m.enterTimer.repeat = true
    m.enterTimer.duration = 0.03
    m.enterTimer.observeField("fire", "onEnterTick")
    m.enterTimer.control = "start"
    m.enterStep = 0
end sub

sub onEnterTick()
    m.enterStep = m.enterStep + 1
    if m.enterStep = 1 then m.brand.opacity = 1
    if m.enterStep = 4 then m.headline.opacity = 1
    if m.enterStep = 7 then m.tagline.opacity = 1
    if m.enterStep = 10 then
        m.profileRow.opacity = 1
        m.enterTimer.control = "stop"
    end if
end sub

sub buildTiles()
    while m.profileRow.getChildCount() > 0
        m.profileRow.removeChildIndex(0)
    end while
    m.tiles = []

    count = m.profiles.count()
    if count = 0 then return
    tileW = 420
    gap = 48
    total = count * tileW + (count - 1) * gap
    startX = Int((1920 - total) / 2)

    for i = 0 to count - 1
        p = m.profiles[i]
        g = m.profileRow.createChild("Group")
        g.translation = [startX + i * (tileW + gap), 0]
        g.scaleRotateCenter = [Int(tileW / 2), 220]

        glow = g.createChild("Rectangle")
        glow.width = tileW + 16
        glow.height = 456
        glow.translation = [-8, -8]
        glow.color = valueOr(p.accent, "0xE50914")
        glow.opacity = 0

        panel = g.createChild("Rectangle")
        panel.width = tileW
        panel.height = 440
        panel.color = "0x141C2C"

        accentBar = g.createChild("Rectangle")
        accentBar.width = tileW
        accentBar.height = 6
        accentBar.color = valueOr(p.accent, "0xE50914")

        avatar = g.createChild("Rectangle")
        avatar.width = 160
        avatar.height = 160
        avatar.translation = [Int((tileW - 160) / 2), 72]
        avatar.color = valueOr(p.accent, "0xE50914")
        avatar.opacity = 0.92

        initial = g.createChild("Label")
        initial.width = 160
        initial.height = 160
        initial.translation = [Int((tileW - 160) / 2), 72]
        initial.horizAlign = "center"
        initial.vertAlign = "center"
        initial.text = UCase(Left(valueOr(p.title, "?"), 1))
        initial.color = "0xFFFFFF"
        initial.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 72)

        titleLbl = g.createChild("Label")
        titleLbl.translation = [24, 270]
        titleLbl.width = tileW - 48
        titleLbl.height = 48
        titleLbl.horizAlign = "center"
        titleLbl.text = valueOr(p.title, "Profile")
        titleLbl.color = "0xFFFFFF"
        titleLbl.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 36)

        blurb = g.createChild("Label")
        blurb.translation = [32, 328]
        blurb.width = tileW - 64
        blurb.height = 72
        blurb.horizAlign = "center"
        blurb.wrap = true
        blurb.maxLines = 2
        blurb.text = valueOr(p.subtitle, "")
        blurb.color = "0x8FA0B8"
        blurb.font = MakeFont("pkg:/fonts/Outfit-Regular.ttf", 22)

        lockLbl = g.createChild("Label")
        lockLbl.translation = [24, 400]
        lockLbl.width = tileW - 48
        lockLbl.height = 28
        lockLbl.horizAlign = "center"
        if valueOr(p.pin, "") <> "" then
            lockLbl.text = "Passcode required"
            lockLbl.color = "0xC5CCD8"
        else
            lockLbl.text = "No passcode"
            lockLbl.color = "0x5E6880"
        end if
        lockLbl.font = MakeFont("pkg:/fonts/Outfit-Medium.ttf", 20)

        m.tiles.push({
            group: g,
            glow: glow,
            panel: panel,
            avatar: avatar,
            profile: p
        })
    end for
end sub

sub buildPinDigits()
    while m.pinDigits.getChildCount() > 0
        m.pinDigits.removeChildIndex(0)
    end while
    m.pinSlots = []
    for i = 0 to 3
        digitBg = m.pinDigits.createChild("Rectangle")
        digitBg.width = 72
        digitBg.height = 88
        digitBg.translation = [i * 96, 0]
        digitBg.color = "0x0E131D"
        digitTxt = m.pinDigits.createChild("Label")
        digitTxt.width = 72
        digitTxt.height = 88
        digitTxt.translation = [i * 96, 0]
        digitTxt.horizAlign = "center"
        digitTxt.vertAlign = "center"
        digitTxt.text = ""
        digitTxt.color = "0xFFFFFF"
        digitTxt.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 40)
        m.pinSlots.push({
            bg: digitBg,
            txt: digitTxt
        })
    end for
end sub

sub paintTiles()
    count = m.profiles.count()
    tileW = 420
    gap = 48
    total = count * tileW + (count - 1) * gap
    startX = Int((1920 - total) / 2)
    for i = 0 to m.tiles.count() - 1
        tile = m.tiles[i]
        focused = false
        if i = m.index then
            if m.pinMode = false then focused = true
        end if
        y = 0
        if focused then
            y = -12
            tile.glow.opacity = 0.55
            tile.panel.color = "0x1A2538"
            tile.group.scale = [1.05, 1.05]
        else
            tile.glow.opacity = 0
            tile.panel.color = "0x141C2C"
            tile.group.scale = [1.0, 1.0]
        end if
        tile.group.translation = [startX + i * (tileW + gap), y]
    end for
end sub

sub paintPin()
    for i = 0 to 3
        slot = m.pinSlots[i]
        if i < Len(m.pinValue) then
            slot.txt.text = "*"
            slot.bg.color = "0x1A2438"
        else if i = Len(m.pinValue) then
            slot.txt.text = ""
            slot.bg.color = "0x2A3348"
        else
            slot.txt.text = ""
            slot.bg.color = "0x0E131D"
        end if
    end for
end sub

sub openPin(profile as Object)
    m.pinMode = true
    m.pinTarget = profile
    m.pinValue = ""
    m.pinError.text = ""
    m.pinTitle.text = "Enter passcode"
    m.pinSub.text = valueOr(profile.title, "Adults") + " profile"
    m.pinOverlay.visible = true
    paintPin()
    paintTiles()
end sub

sub closePin()
    m.pinMode = false
    m.pinTarget = invalid
    m.pinValue = ""
    m.pinOverlay.visible = false
    m.pinError.text = ""
    paintTiles()
end sub

sub appendPinDigit(digit as String)
    if Len(m.pinValue) >= 4 then return
    m.pinValue = m.pinValue + digit
    m.pinError.text = ""
    paintPin()
    if Len(m.pinValue) = 4 then tryUnlock()
end sub

sub nudgePinDigit(goingUp as Boolean)
    if Len(m.pinValue) >= 4 then return
    if Len(m.pinValue) = 0 then
        appendPinDigit("0")
        return
    end if
    last = Mid(m.pinValue, Len(m.pinValue), 1)
    n = Asc(last) - 48
    if n < 0 or n > 9 then n = 0
    if goingUp = true then
        n = n + 1
        if n > 9 then n = 0
    else
        n = n - 1
        if n < 0 then n = 9
    end if
    m.pinValue = Left(m.pinValue, Len(m.pinValue) - 1) + Chr(48 + n)
    m.pinError.text = ""
    paintPin()
end sub

sub backspacePin()
    if Len(m.pinValue) = 0 then
        closePin()
        return
    end if
    m.pinValue = Left(m.pinValue, Len(m.pinValue) - 1)
    paintPin()
end sub

sub tryUnlock()
    if m.pinTarget = invalid then return
    expected = valueOr(m.pinTarget.pin, "")
    if m.pinValue = expected then
        finishSelect(m.pinTarget)
    else
        m.pinError.text = "Incorrect passcode"
        m.pinValue = ""
        paintPin()
    end if
end sub

sub chooseCurrent()
    if m.index < 0 or m.index >= m.profiles.count() then return
    profile = m.profiles[m.index]
    if valueOr(profile.pin, "") <> "" then
        openPin(profile)
    else
        finishSelect(profile)
    end if
end sub

sub finishSelect(profile as Object)
    m.top.selectedProfile = profile
end sub

function valueOr(value as Dynamic, fallback as String) as String
    if value = invalid then return fallback
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return fallback
end function

function digitFromKey(key as String) as String
    if key = "0" or key = "1" or key = "2" or key = "3" or key = "4" then return key
    if key = "5" or key = "6" or key = "7" or key = "8" or key = "9" then return key
    if Left(key, 4) = "lit_" then
        d = Mid(key, 5)
        if Len(d) = 1 and Asc(d) >= 48 and Asc(d) <= 57 then return d
    end if
    return ""
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.pinMode then
        d = digitFromKey(key)
        if d <> "" then
            appendPinDigit(d)
            return true
        end if
        if key = "OK" or key = "play" then
            if Len(m.pinValue) = 4 then tryUnlock()
            return true
        end if
        if key = "back" or key = "rewind" then
            backspacePin()
            return true
        end if
        if key = "right" then
            if Len(m.pinValue) < 4 then appendPinDigit("0")
            return true
        end if
        if key = "left" then
            backspacePin()
            return true
        end if
        if key = "up" or key = "down" then
            goingUp = false
            if key = "up" then goingUp = true
            nudgePinDigit(goingUp)
            return true
        end if
        return true
    end if

    if key = "left" then
        if m.index > 0 then
            m.index = m.index - 1
            paintTiles()
        end if
        return true
    else if key = "right" then
        if m.index < m.profiles.count() - 1 then
            m.index = m.index + 1
            paintTiles()
        end if
        return true
    else if key = "OK" or key = "play" then
        chooseCurrent()
        return true
    else if key = "back" then
        return false
    end if
    return false
end function
