sub init()
    m.statusLabel = m.top.findNode("statusLabel")
    m.sourceList = m.top.findNode("sourceList")
    m.sourceList.observeField("itemSelected", "onSourceSelected")
    m.sources = []
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadSources()
end sub

sub loadSources()
    m.statusLabel.text = "Loading libraries..."
    m.top.loadingMessage = "Loading libraries..."
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "pinnedSources"
    m.task.observeField("response", "onSourcesLoaded")
    m.task.control = "RUN"
end sub

sub onSourcesLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if response = invalid or response.ok <> true then
        err = "Could not load libraries"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    m.sources = response.items
    root = createObject("roSGNode", "ContentNode")
    for each src in m.sources
        child = root.createChild("ContentNode")
        label = asString(src.title)
        sectionType = asString(src.sectionType)
        if sectionType = "movie" then
            label = label + "  ·  Movies"
        else if sectionType = "show" then
            label = label + "  ·  TV"
        end if
        child.title = label
    end for
    m.sourceList.content = root

    if m.sources.count() = 0 then
        m.statusLabel.text = "No movie/TV libraries found on this Plex server"
    else
        m.statusLabel.text = ""
        m.sourceList.jumpToItem = 0
        m.sourceList.setFocus(true)
    end if
end sub

sub onSourceSelected()
    idx = m.sourceList.itemSelected
    if idx = invalid or idx < 0 or idx >= m.sources.count() then return
    m.top.selectedSource = m.sources[idx]
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
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
