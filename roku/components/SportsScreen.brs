sub init()
    m.statusLabel = m.top.findNode("statusLabel")
    m.sportsRows = m.top.findNode("sportsRows")
    m.shimmer = m.top.findNode("shimmer")
    m.sportsRows.observeField("rowItemSelected", "onItemSelected")
    m.events = []
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadFeed()
end sub

sub loadFeed()
    m.statusLabel.text = "Loading sports feed..."
    m.top.loadingMessage = "Loading sports feed..."
    if m.shimmer <> invalid then m.shimmer.active = true
    m.sportsRows.visible = false
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "sportsFeed"
    m.task.observeField("response", "onFeedLoaded")
    m.task.control = "RUN"
end sub

sub onFeedLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if m.shimmer <> invalid then m.shimmer.active = false
    if response = invalid or response.ok <> true then
        err = "Could not load sports feed"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    rows = response.rows
    if rows = invalid then rows = []

    m.events = []
    root = createObject("roSGNode", "ContentNode")
    total = 0
    for each rowData in rows
        row = root.createChild("ContentNode")
        row.title = asString(rowData.title)
        if row.title = "" then row.title = "Live now"
        items = rowData.items
        if items = invalid then items = []
        for each item in items
            m.events.push(item)
            total = total + 1
            child = row.createChild("ContentNode")
            child.title = item.title
            child.hdPosterUrl = item.hdPosterUrl
            child.description = item.description
            child.addFields({ eventIndex: total - 1 })
        end for
    end for

    m.sportsRows.content = root
    if total = 0 then
        m.statusLabel.text = "No live sports found — check sportsFeedUrl in PlexConfig.brs"
    else
        m.statusLabel.text = safeToStr(total) + " events · OK for details & streams"
        m.sportsRows.visible = true
        m.sportsRows.setFocus(true)
    end if
end sub

sub onItemSelected()
    info = m.sportsRows.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.sportsRows.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return

    idx = item.eventIndex
    if idx = invalid or idx < 0 or idx >= m.events.count() then return
    event = m.events[idx]
    if event = invalid then return

    m.top.selectedItem = {
        title: event.title,
        description: event.description,
        mediaType: "sport",
        key: event.key,
        streamUrl: event.streamUrl,
        streams: event.streams,
        hdPosterUrl: event.hdPosterUrl,
        hdBackdropUrl: event.hdBackdropUrl,
        ratingKey: "",
        duration: 0,
        viewOffset: 0
    }
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

function safeToStr(value as Dynamic) as String
    return asString(value)
end function
