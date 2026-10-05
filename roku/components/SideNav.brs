sub init()
    m.navItems = m.top.findNode("navItems")
    m.versionLabel = m.top.findNode("versionLabel")
    m.entries = []
    m.libraries = []
    m.index = 0
    m.itemNodes = []
    buildStaticEntries()
    applyExpanded()
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

    if m.index >= m.entries.count() then m.index = 0
    paint()
end sub

sub paint()
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
    if m.top.expanded = true then
        m.top.visible = true
        m.top.translation = [0, 0]
        m.top.setFocus(true)
        paint()
    else
        m.top.translation = [-310, 0]
        m.top.visible = false
    end if
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
