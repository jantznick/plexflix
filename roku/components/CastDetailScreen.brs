sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.roleLabel = m.top.findNode("roleLabel")
    m.bioLabel = m.top.findNode("bioLabel")
    m.spinner = m.top.findNode("spinner")
    m.creditRows = m.top.findNode("creditRows")
    m.creditRows.observeField("rowItemSelected", "onCreditSelected")
    m.creditRows.observeField("escapeBack", "onEscapeBack")
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return

    m.titleLabel.text = asString(item.title)
    m.roleLabel.text = asString(item.description)
    m.bioLabel.text = ""
    if asString(item.hdPosterUrl) <> "" then m.poster.uri = item.hdPosterUrl

    if m.spinner <> invalid then
        m.spinner.visible = true
        m.spinner.control = "start"
    end if

    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "personDetail"
    m.task.item = item
    m.task.observeField("response", "onLoaded")
    m.task.control = "RUN"
end sub

sub onLoaded()
    if m.spinner <> invalid then
        m.spinner.control = "stop"
        m.spinner.visible = false
    end if

    response = m.task.response
    if response = invalid or response.ok <> true then
        m.bioLabel.text = "Could not load cast details"
        return
    end if

    person = response.person
    if person <> invalid then
        if asString(person.title) <> "" then m.titleLabel.text = person.title
        if asString(person.description) <> "" then m.bioLabel.text = person.description
        if asString(person.hdPosterUrl) <> "" then m.poster.uri = person.hdPosterUrl
        if asString(person.hdBackdropUrl) <> "" then m.backdrop.uri = person.hdBackdropUrl
    end if

    credits = response.credits
    if credits = invalid then credits = []
    root = createObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    row.title = "Known for"
    for each c in credits
        if asString(c.mediaType) = "movie" or asString(c.mediaType) = "show" then
            child = row.createChild("ContentNode")
            child.title = c.title
            child.hdPosterUrl = c.hdPosterUrl
            child.description = c.description
            child.addFields({
                ratingKey: c.ratingKey,
                key: c.key,
                mediaType: c.mediaType,
                year: c.year,
                hdBackdropUrl: c.hdBackdropUrl,
                rating: c.rating,
                contentRating: c.contentRating,
                duration: c.duration,
                viewOffset: c.viewOffset
            })
        end if
    end for
    m.creditRows.content = root
    if row.getChildCount() > 0 then m.creditRows.setFocus(true)
end sub

sub onCreditSelected()
    info = m.creditRows.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.creditRows.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return
    ' Only open Plex-backed titles (need ratingKey)
    if asString(item.ratingKey) = "" then return
    m.top.openDetails = {
        title: item.title,
        description: item.description,
        year: item.year,
        rating: item.rating,
        contentRating: item.contentRating,
        mediaType: item.mediaType,
        ratingKey: item.ratingKey,
        key: item.key,
        hdPosterUrl: item.hdPosterUrl,
        hdBackdropUrl: item.hdBackdropUrl,
        duration: item.duration,
        viewOffset: item.viewOffset
    }
end sub

sub onEscapeBack()
    m.top.closed = true
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        m.top.closed = true
        return true
    end if
    return false
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return ""
end function
