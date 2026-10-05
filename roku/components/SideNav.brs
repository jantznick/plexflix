sub init()
    m.navList = m.top.findNode("navList")
    m.brandLabel = m.top.findNode("brandLabel")
    m.navList.observeField("itemSelected", "onItemSelected")

    m.entries = []
    m.libraries = []
    buildStaticEntries()
    applyExpanded()
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadLibraries()
end sub

sub buildStaticEntries()
    m.entries = [
        { id: "home", kind: "nav", title: "Home" },
        { id: "sports", kind: "nav", title: "Live Sports" }
    ]
    paintList()
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
    m.entries.push({ id: "sports", kind: "nav", title: "Live Sports" })
    paintList()
    syncActiveIndex()
end sub

sub paintList()
    root = createObject("roSGNode", "ContentNode")
    for each entry in m.entries
        child = root.createChild("ContentNode")
        child.title = entry.title
    end for
    m.navList.content = root
end sub

sub onExpandedChange()
    applyExpanded()
end sub

sub applyExpanded()
    if m.top.expanded = true then
        m.top.visible = true
        m.top.translation = [0, 0]
        m.navList.setFocus(true)
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
            m.navList.jumpToItem = i
            return
        end if
    end for
end sub

sub onItemSelected()
    idx = m.navList.itemSelected
    if idx = invalid or idx < 0 or idx >= m.entries.count() then return
    entry = m.entries[idx]

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
    if key = "back" then
        m.top.expanded = false
        return true
    else if key = "right" then
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
