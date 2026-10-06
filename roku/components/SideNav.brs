sub init()
    m.navItems = m.top.findNode("navItems")
    m.versionLabel = m.top.findNode("versionLabel")
    m.full = m.top.findNode("full")
    m.mini = m.top.findNode("mini")
    m.miniItems = m.top.findNode("miniItems")
    m.entries = []
    m.libraries = []
    m.index = 0
    m.activeIndex = 0
    m.itemNodes = []
    m.miniNodes = []
    buildStaticEntries()
    applyExpanded()
    ' Screens finishing a load call setFocus on their own lists; while the
    ' menu is open (it starts open) that would strand it without the remote
    m.top.observeField("focusedChild", "onFocusChainChange")
end sub

sub onFocusChainChange()
    if m.top.expanded = true and m.top.suppressed <> true and not m.top.isInFocusChain() then m.top.setFocus(true)
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    if m.versionLabel <> invalid and m.top.config.version <> invalid then
        m.versionLabel.text = "v" + m.top.config.version
    end if
    loadLibraries()
end sub

sub buildStaticEntries()
    m.entries = [
        { id: "home", kind: "nav", title: "Home" },
        { id: "livetv", kind: "nav", title: "Live TV" },
        { id: "sports", kind: "nav", title: "Live Sports" }
    ]
    rebuildItems()
end sub

sub loadLibraries()
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "pinnedSources"
    m.task.observeField("response", "onLibrariesLoaded")
    m.task.control = "RUN"
end sub

sub onLibrariesLoaded()
    response = m.task.response
    m.libraries = []
    if response <> invalid and response.ok = true and response.items <> invalid then
        m.libraries = response.items
    end if

    m.entries = []
    m.entries.push({ id: "home", kind: "nav", title: "Home" })
    for each lib in m.libraries
        m.entries.push({
            id: "lib:" + asString(lib.sectionId),
            kind: "library",
            title: asString(lib.title),
            library: lib
        })
    end for
    m.entries.push({ id: "livetv", kind: "nav", title: "Live TV" })
    m.entries.push({ id: "sports", kind: "nav", title: "Live Sports" })
    rebuildItems()
    syncActiveIndex()
end sub

sub rebuildItems()
    while m.navItems.getChildCount() > 0
        m.navItems.removeChildIndex(0)
    end while
    m.itemNodes = []

    y = 0
    for i = 0 to m.entries.count() - 1
        entry = m.entries[i]
        row = createObject("roSGNode", "Group")
        row.translation = [0, y]

        bg = createObject("roSGNode", "Rectangle")
        bg.id = "bg"
        bg.width = 260
        bg.height = 56
        bg.color = "0x1E1E24"
        row.appendChild(bg)

        label = createObject("roSGNode", "Label")
        label.width = 260
        label.height = 56
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.text = entry.title
        label.color = "0xDDDDDD"
        label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 24)
        row.appendChild(label)

        m.navItems.appendChild(row)
        m.itemNodes.push({ group: row, bg: bg, label: label })
        y = y + 64
    end for

    rebuildMini()
    if m.index >= m.entries.count() then m.index = 0
    if m.activeIndex >= m.entries.count() then m.activeIndex = 0
    paint()
end sub

' Same vertical rhythm as the full list, so an icon sits where its label will
' appear when the menu opens
sub rebuildMini()
    while m.miniItems.getChildCount() > 0
        m.miniItems.removeChildIndex(0)
    end while
    m.miniNodes = []

    y = 0
    for each entry in m.entries
        marker = m.miniItems.createChild("Rectangle")
        marker.width = 4
        marker.height = 40
        marker.translation = [0, y + 8]
        marker.color = "0xE50914"
        marker.visible = false

        icon = m.miniItems.createChild("Poster")
        icon.width = 36
        icon.height = 36
        icon.translation = [18, y + 10]
        icon.uri = iconFor(entry)

        m.miniNodes.push({ marker: marker, icon: icon })
        y = y + 64
    end for
end sub

function iconFor(entry as Object) as String
    if entry.id = "home" then return "pkg:/images/nav_home.png"
    if entry.id = "livetv" then return "pkg:/images/nav_live.png"
    if entry.id = "sports" then return "pkg:/images/nav_sports.png"
    if entry.library <> invalid and asString(entry.library.sectionType) = "show" then
        return "pkg:/images/nav_tv.png"
    end if
    return "pkg:/images/nav_movie.png"
end function

sub paint()
    for i = 0 to m.miniNodes.count() - 1
        node = m.miniNodes[i]
        isActive = (i = m.activeIndex)
        node.marker.visible = isActive
        if isActive then node.icon.blendColor = "0xFFFFFF" else node.icon.blendColor = "0x77777F"
    end for

    for i = 0 to m.itemNodes.count() - 1
        node = m.itemNodes[i]
        if i = m.index then
            node.bg.color = "0xE50914"
            node.label.color = "0xFFFFFF"
        else
            node.bg.color = "0x1E1E24"
            node.label.color = "0xCCCCCC"
        end if
    end for
end sub

sub onExpandedChange()
    applyExpanded()
end sub

sub applyExpanded()
    m.top.translation = [0, 0]
    if m.top.suppressed = true then
        m.top.visible = false
        return
    end if
    m.top.visible = true
    if m.top.expanded = true then
        m.full.visible = true
        m.mini.visible = false
        m.top.setFocus(true)
    else
        m.full.visible = false
        m.mini.visible = (m.top.railVisible = true)
        ' Reopening should start on the section you are in, not wherever the
        ' cursor was left when the menu was dismissed without a choice
        m.index = m.activeIndex
    end if
    paint()
end sub

sub onActiveChange()
    syncActiveIndex()
end sub

sub syncActiveIndex()
    active = m.top.active
    if active = invalid or active = "" then return
    for i = 0 to m.entries.count() - 1
        if m.entries[i].id = active then
            m.index = i
            m.activeIndex = i
            paint()
            return
        end if
    end for
end sub

sub activateCurrent()
    if m.index < 0 or m.index >= m.entries.count() then return
    entry = m.entries[m.index]
    if entry.kind = "library" then
        m.top.active = entry.id
        m.top.selectedLibrary = entry.library
        m.top.selected = "library"
        return
    end if
    m.top.active = entry.id
    m.top.selected = entry.id
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
        if m.index < m.entries.count() - 1 then
            m.index = m.index + 1
            paint()
        end if
        return true
    else if key = "OK" or key = "play"
        activateCurrent()
        return true
    else if key = "back"
        m.top.expanded = false
        return true
    else if key = "right"
        return false
    end if
    return false
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    return ""
end function
