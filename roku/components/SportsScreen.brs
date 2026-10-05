sub init()
    m.statusLabel = m.top.findNode("statusLabel")
    m.sportsRows = m.top.findNode("sportsRows")
    m.sportsRows.observeField("rowItemSelected", "onItemSelected")
    m.items = []
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadFeed()
end sub

sub loadFeed()
    m.statusLabel.text = "Loading sports feed..."
    m.top.loadingMessage = "Loading sports feed..."
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "sportsFeed"
    m.task.observeField("response", "onFeedLoaded")
    m.task.control = "RUN"
end sub

sub onFeedLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if response = invalid or response.ok <> true then
        err = "Could not load sports feed"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    rows = response.rows
    if rows = invalid then rows = []

    root = createObject("roSGNode", "ContentNode")
    total = 0
    for each rowData in rows
        row = root.createChild("ContentNode")
        row.title = asString(rowData.title)
        if row.title = "" then row.title = "Live now"
        items = rowData.items
        if items = invalid then items = []
        for each item in items
            total = total + 1
            child = row.createChild("ContentNode")
            child.title = item.title
            child.hdPosterUrl = item.hdPosterUrl
            child.description = item.description
            child.addFields({
                mediaType: "sport",
                key: item.key,
                streamUrl: item.streamUrl,
                ratingKey: "",
                duration: 0,
                viewOffset: 0
            })
        end for
    end for

    m.sportsRows.content = root
    if total = 0 then
        m.statusLabel.text = "No live sports found in feed"
    else
        m.statusLabel.text = ""
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
    m.top.selectedItem = {
        title: item.title,
        description: item.description,
        mediaType: "sport",
        key: item.key,
        streamUrl: item.streamUrl,
        hdPosterUrl: item.hdPosterUrl,
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
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        return Str(value).Trim()
    end if
    return ""
end function
