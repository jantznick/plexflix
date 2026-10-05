sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.roleLabel = m.top.findNode("roleLabel")
    m.bioLabel = m.top.findNode("bioLabel")
    m.spinner = m.top.findNode("spinner")
    m.backBg = m.top.findNode("backBg")
    m.backLabel = m.top.findNode("backLabel")
    m.creditRows = m.top.findNode("creditRows")
    m.focusZone = "back" ' back | rows
    if m.creditRows <> invalid then m.creditRows.focusable = false
    m.creditRows.observeField("rowItemSelected", "onCreditSelected")
    m.creditRows.observeField("escapeBack", "onEscapeBack")
    m.creditRows.observeField("escapeUp", "onEscapeUp")
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

    m.focusZone = "back"
    paintBackFocus()
    m.top.setFocus(true)

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
        meta = asString(person.metaLine)
        if meta = "" then meta = asString(person.knownFor)
        if meta = "" then meta = asString(m.top.content.description)
        m.roleLabel.text = meta
        if asString(person.description) <> "" then m.bioLabel.text = person.description
        if asString(person.hdPosterUrl) <> "" then m.poster.uri = person.hdPosterUrl
        if asString(person.hdBackdropUrl) <> "" then m.backdrop.uri = person.hdBackdropUrl
    end if

    movies = response.movies
    shows = response.shows
    credits = response.credits
    if movies = invalid then movies = []
    if shows = invalid then shows = []
    if credits = invalid then credits = []

    root = createObject("roSGNode", "ContentNode")
    added = 0
    if movies.count() > 0 then
        appendCreditRow(root, "Movies", movies)
        added = added + 1
    end if
    if shows.count() > 0 then
        appendCreditRow(root, "TV Shows", shows)
        added = added + 1
    end if
    if added = 0 and credits.count() > 0 then
        appendCreditRow(root, "Known for", credits)
        added = 1
    end if

    m.creditRows.content = root
    m.focusZone = "back"
    if m.creditRows <> invalid then m.creditRows.focusable = false
    paintBackFocus()
    m.top.setFocus(true)
end sub

sub appendCreditRow(root as Object, title as String, list as Object)
    row = root.createChild("ContentNode")
    row.title = title
    maxN = list.count()
    if maxN > 40 then maxN = 40
    for i = 0 to maxN - 1
        c = list[i]
        if c <> invalid and (asString(c.mediaType) = "movie" or asString(c.mediaType) = "show" or asString(c.mediaType) = "") then
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
                viewOffset: c.viewOffset,
                watched: c.watched,
                unwatchedCount: c.unwatchedCount,
                viewedLeafCount: c.viewedLeafCount,
                leafCount: c.leafCount
            })
        end if
    end for
end sub

sub paintBackFocus()
    if m.backBg = invalid then return
    if m.focusZone = "back" then
        ' Focused: white plate + dark label so Back is always readable
        m.backBg.color = "0xFFFFFF"
        if m.backLabel <> invalid then m.backLabel.color = "0x111118"
    else
        m.backBg.color = "0x2A2A32"
        if m.backLabel <> invalid then m.backLabel.color = "0xFFFFFF"
    end if
end sub

sub onCreditSelected()
    info = m.creditRows.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.creditRows.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return
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
        viewOffset: item.viewOffset,
        watched: item.watched,
        unwatchedCount: item.unwatchedCount,
        viewedLeafCount: item.viewedLeafCount,
        leafCount: item.leafCount
    }
end sub

sub onEscapeBack()
    m.top.closed = true
end sub

sub onEscapeUp()
    m.focusZone = "back"
    if m.creditRows <> invalid then m.creditRows.focusable = false
    paintBackFocus()
    m.top.setFocus(true)
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

    if m.focusZone = "back" then
        if key = "OK" then
            m.top.closed = true
            return true
        else if key = "down" then
            if m.creditRows.content <> invalid and m.creditRows.content.getChildCount() > 0 then
                m.focusZone = "rows"
                paintBackFocus()
                m.creditRows.focusable = true
                m.creditRows.setFocus(true)
                return true
            end if
        end if
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
