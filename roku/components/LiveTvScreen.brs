sub init()
    m.statusLabel = m.top.findNode("statusLabel")
    m.liveRows = m.top.findNode("liveRows")
    m.shimmer = m.top.findNode("shimmer")
    m.liveRows.observeField("rowItemSelected", "onItemSelected")
    m.liveRows.observeField("escapeLeft", "onEscapeLeft")
    m.events = []
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadLiveTv()
end sub

sub loadLiveTv()
    m.statusLabel.text = "Loading Live TV..."
    m.top.loadingMessage = "Loading Live TV..."
    if m.shimmer <> invalid then m.shimmer.active = true
    m.liveRows.visible = false
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "liveTv"
    m.task.observeField("response", "onLoaded")
    m.task.control = "RUN"
end sub

sub onLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if m.shimmer <> invalid then m.shimmer.active = false

    if response = invalid or response.ok <> true then
        err = "Could not load Live TV"
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
        if row.title = "" then row.title = "Live TV"
        items = rowData.items
        if items = invalid then items = []
        for each item in items
            m.events.push(item)
            total = total + 1
            child = row.createChild("ContentNode")
            child.title = item.title
            child.hdPosterUrl = item.hdPosterUrl
            child.description = item.description
            child.addFields({
                eventIndex: total - 1,
                mediaType: item.mediaType,
                ratingKey: item.ratingKey,
                key: item.key,
                channelId: item.channelId,
                dvrId: item.dvrId,
                duration: item.duration,
                viewOffset: item.viewOffset,
                hdBackdropUrl: item.hdBackdropUrl,
                year: item.year,
                rating: item.rating,
                contentRating: item.contentRating
            })
        end for
    end for

    m.liveRows.content = root
    if total = 0 then
        m.statusLabel.text = "No channels or recordings found"
    else
        m.statusLabel.text = ""
        m.liveRows.visible = true
        m.liveRows.setFocus(true)
    end if
end sub

sub onItemSelected()
    info = m.liveRows.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.liveRows.content.getChild(info[0])
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
        mediaType: event.mediaType,
        ratingKey: event.ratingKey,
        key: event.key,
        channelId: event.channelId,
        dvrId: event.dvrId,
        hdPosterUrl: event.hdPosterUrl,
        hdBackdropUrl: event.hdBackdropUrl,
        duration: event.duration,
        viewOffset: event.viewOffset,
        year: event.year,
        rating: event.rating,
        contentRating: event.contentRating
    }
end sub

sub onEscapeLeft()
    m.top.openMenu = true
end sub

sub onRefocus()
    if m.top.refocus = true and m.liveRows <> invalid then
        m.liveRows.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "left" then
        m.top.openMenu = true
        return true
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
