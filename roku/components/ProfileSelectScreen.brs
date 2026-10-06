sub init()
    m.profilesGroup = m.top.findNode("profiles")
    m.pinOverlay = m.top.findNode("pinOverlay")
    m.pinTitle = m.top.findNode("pinTitle")
    m.pinHint = m.top.findNode("pinHint")
    m.pinError = m.top.findNode("pinError")
    m.pinDots = m.top.findNode("pinDots")
    m.pinPad = m.top.findNode("pinPad")
    m.heading = m.top.findNode("heading")
    m.subheading = m.top.findNode("subheading")

    m.mode = "pick" ' pick | pin
    m.focusIndex = 0
    m.pinDigits = ""
    m.pinFocus = 0
    m.profileNodes = []
    m.dotNodes = []
    m.padNodes = []
    m.adultName = "Nick"
    m.kidsName = "Kids"
    m.expectedPin = "1234"

    buildProfiles()
    buildPinUi()
    paintProfiles()
    m.top.setFocus(true)
end sub

sub onConfigReady()
    cfg = m.top.config
    if cfg = invalid then return
    m.adultName = AdultProfileName(cfg)
    m.kidsName = KidsProfileName(cfg)
    m.expectedPin = AdultPin(cfg)
    if m.expectedPin = "" then m.expectedPin = "1234"
    rebuildProfileLabels()
    if m.pinHint <> invalid then
        m.pinHint.text = "PIN for " + m.adultName
    end if
end sub

sub buildProfiles()
    while m.profilesGroup.getChildCount() > 0
        m.profilesGroup.removeChildIndex(0)
    end while
    m.profileNodes = []

    adult = makeProfileTile(0, m.adultName, "0xE50914", "N")
    kids = makeProfileTile(1, m.kidsName, "0x2BB673", "K")
    m.profilesGroup.appendChild(adult.group)
    m.profilesGroup.appendChild(kids.group)
    m.profileNodes.push(adult)
    m.profileNodes.push(kids)
end sub

function makeProfileTile(index as Integer, name as String, accent as String, initial as String) as Object
    group = createObject("roSGNode", "Group")
    group.translation = [index * 420, 0]

    ring = createObject("roSGNode", "Rectangle")
    ring.id = "ring"
    ring.width = 220
    ring.height = 220
    ring.color = "0x2A2A32"
    group.appendChild(ring)

    avatar = createObject("roSGNode", "Rectangle")
    avatar.id = "avatar"
    avatar.width = 196
    avatar.height = 196
    avatar.translation = [12, 12]
    avatar.color = accent
    group.appendChild(avatar)

    letter = createObject("roSGNode", "Label")
    letter.id = "letter"
    letter.width = 196
    letter.height = 196
    letter.translation = [12, 12]
    letter.horizAlign = "center"
    letter.vertAlign = "center"
    letter.text = Left(name, 1)
    if letter.text = "" then letter.text = initial
    letter.color = "0xFFFFFF"
    letter.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 72)
    group.appendChild(letter)

    label = createObject("roSGNode", "Label")
    label.id = "label"
    label.width = 220
    label.height = 48
    label.translation = [0, 244]
    label.horizAlign = "center"
    label.text = name
    label.color = "0xDDDDDD"
    label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 28)
    group.appendChild(label)

    return {
        group: group,
        ring: ring,
        avatar: avatar,
        letter: letter,
        label: label,
        name: name,
        accent: accent,
        mode: iif(index = 0, "adult", "kids")
    }
end function

function iif(cond as Boolean, a as String, b as String) as String
    if cond then return a
    return b
end function

sub rebuildProfileLabels()
    if m.profileNodes.count() < 2 then return
    m.profileNodes[0].name = m.adultName
    m.profileNodes[0].mode = "adult"
    m.profileNodes[0].label.text = m.adultName
    m.profileNodes[0].letter.text = Left(m.adultName, 1)

    m.profileNodes[1].name = m.kidsName
    m.profileNodes[1].mode = "kids"
    m.profileNodes[1].label.text = m.kidsName
    m.profileNodes[1].letter.text = Left(m.kidsName, 1)
end sub

sub paintProfiles()
    for i = 0 to m.profileNodes.count() - 1
        node = m.profileNodes[i]
        if i = m.focusIndex then
            node.ring.color = "0xFFFFFF"
            node.label.color = "0xFFFFFF"
        else
            node.ring.color = "0x2A2A32"
            node.label.color = "0xAAAAAA"
        end if
    end for
end sub

sub buildPinUi()
    while m.pinDots.getChildCount() > 0
        m.pinDots.removeChildIndex(0)
    end while
    m.dotNodes = []
    for i = 0 to 3
        dot = createObject("roSGNode", "Rectangle")
        dot.width = 28
        dot.height = 28
        dot.translation = [i * 76, 0]
        dot.color = "0x2A2A32"
        m.pinDots.appendChild(dot)
        m.dotNodes.push(dot)
    end for

    while m.pinPad.getChildCount() > 0
        m.pinPad.removeChildIndex(0)
    end while
    m.padNodes = []

    keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "clr", "0", "ok"]
    for i = 0 to keys.count() - 1
        key = keys[i]
        col = i MOD 3
        row = Int(i / 3)
        cell = createObject("roSGNode", "Group")
        cell.translation = [col * 140, row * 90]

        bg = createObject("roSGNode", "Rectangle")
        bg.width = 120
        bg.height = 72
        bg.color = "0x2A2A32"
        cell.appendChild(bg)

        label = createObject("roSGNode", "Label")
        label.width = 120
        label.height = 72
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.color = "0xFFFFFF"
        if key = "clr" then
            label.text = "Clear"
            label.font = MakeFont("pkg:/fonts/Outfit-Medium.ttf", 22)
        else if key = "ok" then
            label.text = "OK"
            label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 26)
        else
            label.text = key
            label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 30)
        end if
        cell.appendChild(label)

        m.pinPad.appendChild(cell)
        m.padNodes.push({ group: cell, bg: bg, label: label, key: key })
    end for
    paintPin()
end sub

sub paintPin()
    for i = 0 to m.dotNodes.count() - 1
        if i < Len(m.pinDigits) then
            m.dotNodes[i].color = "0xE50914"
        else
            m.dotNodes[i].color = "0x2A2A32"
        end if
    end for

    for i = 0 to m.padNodes.count() - 1
        node = m.padNodes[i]
        if i = m.pinFocus then
            node.bg.color = "0xFFFFFF"
            node.label.color = "0x111118"
        else
            node.bg.color = "0x2A2A32"
            node.label.color = "0xFFFFFF"
        end if
    end for
end sub

sub showPin()
    m.mode = "pin"
    m.pinDigits = ""
    m.pinFocus = 0
    if m.pinError <> invalid then m.pinError.text = ""
    if m.pinTitle <> invalid then m.pinTitle.text = "Enter PIN"
    if m.pinHint <> invalid then m.pinHint.text = "PIN for " + m.adultName
    if m.heading <> invalid then m.heading.visible = false
    if m.subheading <> invalid then m.subheading.visible = false
    if m.profilesGroup <> invalid then m.profilesGroup.visible = false
    m.pinOverlay.visible = true
    paintPin()
end sub

sub hidePin()
    m.mode = "pick"
    m.pinDigits = ""
    m.pinOverlay.visible = false
    if m.heading <> invalid then m.heading.visible = true
    if m.subheading <> invalid then m.subheading.visible = true
    if m.profilesGroup <> invalid then m.profilesGroup.visible = true
    if m.pinError <> invalid then m.pinError.text = ""
    paintProfiles()
end sub

sub activateProfile()
    if m.focusIndex < 0 or m.focusIndex >= m.profileNodes.count() then return
    choice = m.profileNodes[m.focusIndex]
    if choice.mode = "kids" then
        finishProfile("kids", choice.name)
    else
        showPin()
    end if
end sub

sub finishProfile(mode as String, name as String)
    m.top.selectedProfile = { mode: mode, name: name }
end sub

sub appendPinDigit(digit as String)
    if Len(m.pinDigits) >= 4 then return
    m.pinDigits = m.pinDigits + digit
    if m.pinError <> invalid then m.pinError.text = ""
    paintPin()
    if Len(m.pinDigits) = 4 then validatePin()
end sub

sub clearPin()
    m.pinDigits = ""
    if m.pinError <> invalid then m.pinError.text = ""
    paintPin()
end sub

sub validatePin()
    if m.pinDigits = m.expectedPin then
        finishProfile("adult", m.adultName)
        return
    end if
    if m.pinError <> invalid then m.pinError.text = "Incorrect PIN"
    m.pinDigits = ""
    paintPin()
end sub

sub activatePadKey()
    if m.pinFocus < 0 or m.pinFocus >= m.padNodes.count() then return
    key = m.padNodes[m.pinFocus].key
    if key = "clr" then
        clearPin()
    else if key = "ok" then
        if Len(m.pinDigits) = 4 then
            validatePin()
        else if m.pinError <> invalid then
            m.pinError.text = "Enter all 4 digits"
        end if
    else
        appendPinDigit(key)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.mode = "pin" then
        if key = "back" then
            hidePin()
            return true
        else if key = "left" then
            if (m.pinFocus MOD 3) > 0 then
                m.pinFocus = m.pinFocus - 1
                paintPin()
            end if
            return true
        else if key = "right" then
            if (m.pinFocus MOD 3) < 2 then
                m.pinFocus = m.pinFocus + 1
                paintPin()
            end if
            return true
        else if key = "up" then
            if m.pinFocus >= 3 then
                m.pinFocus = m.pinFocus - 3
                paintPin()
            end if
            return true
        else if key = "down" then
            if m.pinFocus + 3 < m.padNodes.count() then
                m.pinFocus = m.pinFocus + 3
                paintPin()
            end if
            return true
        else if key = "OK" or key = "play" then
            activatePadKey()
            return true
        else if Len(key) = 1 and Instr(1, "0123456789", key) > 0 then
            appendPinDigit(key)
            return true
        end if
        return true
    end if

    ' Profile picker
    if key = "left" then
        if m.focusIndex > 0 then
            m.focusIndex = m.focusIndex - 1
            paintProfiles()
        end if
        return true
    else if key = "right" then
        if m.focusIndex < m.profileNodes.count() - 1 then
            m.focusIndex = m.focusIndex + 1
            paintProfiles()
        end if
        return true
    else if key = "OK" or key = "play" then
        activateProfile()
        return true
    else if key = "back" then
        ' Stay on the gate — nothing sits behind it yet
        return true
    end if
    return false
end function
