sub init()
    m.profileRow = m.top.findNode("profileRow")
    m.pinOverlay = m.top.findNode("pinOverlay")
    m.pinTitle = m.top.findNode("pinTitle")
    m.pinDigits = m.top.findNode("pinDigits")
    m.pinKeypad = m.top.findNode("pinKeypad")
    m.pinError = m.top.findNode("pinError")
    m.brand = m.top.findNode("brand")
    m.headline = m.top.findNode("headline")

    m.profiles = GetProfiles()
    m.index = 0
    m.tiles = []
    m.pinMode = false
    m.pinValue = ""
    m.pinTarget = invalid
    m.pinSlots = []
    m.pinKeys = []
    m.pinKeyIndex = 0

    buildTiles()
    buildPinDigits()
    buildPinKeypad()
    paintTiles()
    m.top.setFocus(true)

    m.brand.opacity = 0
    m.headline.opacity = 0
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
    if m.enterStep = 8 then
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
        g.scaleRotateCenter = [Int(tileW / 2), 200]

        glow = g.createChild("Rectangle")
        glow.width = tileW + 16
        glow.height = 400
        glow.translation = [-8, -8]
        glow.color = valueOr(p.accent, "0xE50914")
        glow.opacity = 0

        panel = g.createChild("Rectangle")
        panel.width = tileW
        panel.height = 384
        panel.color = "0x141C2C"

        accentBar = g.createChild("Rectangle")
        accentBar.width = tileW
        accentBar.height = 6
        accentBar.color = valueOr(p.accent, "0xE50914")

        avatar = g.createChild("Rectangle")
        avatar.width = 160
        avatar.height = 160
        avatar.translation = [Int((tileW - 160) / 2), 56]
        avatar.color = valueOr(p.accent, "0xE50914")
        avatar.opacity = 0.92

        initial = g.createChild("Label")
        initial.width = 160
        initial.height = 160
        initial.translation = [Int((tileW - 160) / 2), 56]
        initial.horizAlign = "center"
        initial.vertAlign = "center"
        initial.text = UCase(Left(valueOr(p.title, "?"), 1))
        initial.color = "0xFFFFFF"
        initial.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 72)

        titleLbl = g.createChild("Label")
        titleLbl.translation = [24, 248]
        titleLbl.width = tileW - 48
        titleLbl.height = 56
        titleLbl.horizAlign = "center"
        titleLbl.vertAlign = "center"
        titleLbl.text = valueOr(p.title, "Profile")
        titleLbl.color = "0xFFFFFF"
        titleLbl.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 40)

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

sub buildPinKeypad()
    while m.pinKeypad.getChildCount() > 0
        m.pinKeypad.removeChildIndex(0)
    end while
    m.pinKeys = []

    ' Phone layout: 1-9, then Del + 0
    labels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Del", "0"]
    actions = ["", "", "", "", "", "", "", "", "", "del", ""]
    cellW = 96
    cellH = 72
    gapX = 16
    gapY = 14
    gridW = 3 * cellW + 2 * gapX
    startX = Int((880 - 8 - gridW) / 2) - 88

    for i = 0 to labels.count() - 1
        row = Int(i / 3)
        col = i mod 3
        if i = 9 then
            row = 3
            col = 0
        else if i = 10 then
            row = 3
            col = 1
        end if

        g = m.pinKeypad.createChild("Group")
        g.translation = [startX + col * (cellW + gapX), row * (cellH + gapY)]

        bg = g.createChild("Rectangle")
        bg.width = cellW
        bg.height = cellH
        bg.color = "0x1A2438"

        lbl = g.createChild("Label")
        lbl.width = cellW
        lbl.height = cellH
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        lbl.text = labels[i]
        lbl.color = "0xFFFFFF"
        if labels[i] = "Del" then
            lbl.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 26)
        else
            lbl.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 36)
        end if

        entry = {
            group: g,
            bg: bg,
            row: row,
            col: col,
            label: labels[i]
        }
        if actions[i] = "del" then
            entry.action = "del"
        else
            entry.digit = labels[i]
        end if
        m.pinKeys.push(entry)
    end for
    m.pinKeyIndex = 4
    paintPinKeypad()
end sub

sub paintPinKeypad()
    for i = 0 to m.pinKeys.count() - 1
        keyEntry = m.pinKeys[i]
        if i = m.pinKeyIndex then
            keyEntry.bg.color = "0xE50914"
        else
            keyEntry.bg.color = "0x1A2438"
        end if
    end for
end sub

function pinKeyIndexAt(row as Integer, col as Integer) as Integer
    for i = 0 to m.pinKeys.count() - 1
        keyEntry = m.pinKeys[i]
        if keyEntry.row = row and keyEntry.col = col then return i
    end for
    return -1
end function

sub movePinKey(deltaRow as Integer, deltaCol as Integer)
    if m.pinKeys.count() = 0 then return
    keyEntry = m.pinKeys[m.pinKeyIndex]
    row = keyEntry.row + deltaRow
    col = keyEntry.col + deltaCol
    if row < 0 or row > 3 then return
    if col < 0 or col > 2 then return
    idx = pinKeyIndexAt(row, col)
    if idx >= 0 then
        m.pinKeyIndex = idx
        paintPinKeypad()
    end if
end sub

sub activatePinKey()
    if m.pinKeyIndex < 0 or m.pinKeyIndex >= m.pinKeys.count() then return
    keyEntry = m.pinKeys[m.pinKeyIndex]
    if keyEntry.action = "del" then
        if Len(m.pinValue) > 0 then
            m.pinValue = Left(m.pinValue, Len(m.pinValue) - 1)
            m.pinError.text = ""
            paintPin()
        end if
        return
    end if
    if keyEntry.digit <> invalid and keyEntry.digit <> "" then
        appendPinDigit(keyEntry.digit)
    end if
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
    m.pinOverlay.visible = true
    m.pinKeyIndex = 4
    paintPin()
    paintPinKeypad()
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
            activatePinKey()
            return true
        end if
        if key = "back" then
            closePin()
            return true
        end if
        if key = "left" then
            movePinKey(0, -1)
            return true
        else if key = "right" then
            movePinKey(0, 1)
            return true
        else if key = "up" then
            movePinKey(-1, 0)
            return true
        else if key = "down" then
            movePinKey(1, 0)
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
