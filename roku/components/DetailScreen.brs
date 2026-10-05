sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")

    m.movieActions = m.top.findNode("movieActions")
    m.playBg = m.top.findNode("playBg")
    m.backBg = m.top.findNode("backBg")
    m.playLabel = m.top.findNode("playLabel")

    m.tvPanel = m.top.findNode("tvPanel")
    m.seasonRows = m.top.findNode("seasonRows")
    m.seasonRows.observeField("rowItemSelected", "onEpisodeSelected")

    m.focusIndex = 0
    m.isShow = false
    m.seasons = []
    m.seasonQueue = 0
    m.seasonContent = invalid
    m.pendingSeason = invalid

    updateMovieButtonFocus()
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return

    m.titleLabel.text = asString(item.title)
    m.summaryLabel.text = asString(item.description)

    metaBits = []
    year = asString(item.year)
    if year <> "" then metaBits.push(year)
    contentRating = asString(item.contentRating)
    if contentRating <> "" then metaBits.push(contentRating)
    rating = asString(item.rating)
    if rating <> "" then metaBits.push(rating + " ★")
    mediaType = asString(item.mediaType)
    if mediaType <> "" then metaBits.push(titleCaseType(mediaType))
    m.metaLabel.text = joinStrings(metaBits, "  ·  ")

    if item.hdBackdropUrl <> invalid and item.hdBackdropUrl <> "" then
        m.backdrop.uri = item.hdBackdropUrl
    end if
    if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
        m.poster.uri = item.hdPosterUrl
    end if

    m.isShow = (mediaType = "show" or mediaType = "season")
    if mediaType = "show" then
        showTvMode()
        loadChildren(item, "seasons")
    else if mediaType = "season" then
        showTvMode()
        m.seasons = [item]
        m.seasonQueue = 0
        m.seasonContent = createObject("roSGNode", "ContentNode")
        m.seasonRows.content = m.seasonContent
        loadSeasonEpisodes()
    else
        m.movieActions.visible = true
        m.tvPanel.visible = false
        m.playLabel.text = "Play"
        m.poster.visible = true
    end if
end sub

sub showTvMode()
    m.movieActions.visible = false
    m.tvPanel.visible = true
    ' Give episode rails the full width; keep a compact show poster
    m.poster.width = 220
    m.poster.height = 330
    m.poster.translation = [80, 70]
end sub

sub loadChildren(item as Object, mode as String)
    m.loadMode = mode
    m.pendingSeason = item
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "children"
    m.task.item = item
    m.task.observeField("response", "onChildrenLoaded")
    m.task.control = "RUN"
end sub

sub onChildrenLoaded()
    response = m.task.response
    if response = invalid or response.ok <> true then
        return
    end if

    items = response.items
    if items = invalid then items = []

    if m.loadMode = "seasons" then
        m.seasons = items
        m.seasonQueue = 0
        m.seasonContent = createObject("roSGNode", "ContentNode")
        m.seasonRows.content = m.seasonContent
        if items.count() = 0 then return
        loadSeasonEpisodes()
    else if m.loadMode = "episodes" then
        appendSeasonRow(m.pendingSeason, items)
        m.seasonQueue = m.seasonQueue + 1
        loadSeasonEpisodes()
    end if
end sub

sub loadSeasonEpisodes()
    if m.seasons = invalid or m.seasonQueue >= m.seasons.count() then
        if m.seasonContent <> invalid and m.seasonContent.getChildCount() > 0 then
            m.seasonRows.setFocus(true)
        end if
        return
    end if
    loadChildren(m.seasons[m.seasonQueue], "episodes")
end sub

sub appendSeasonRow(season as Object, episodes as Object)
    if m.seasonContent = invalid then
        m.seasonContent = createObject("roSGNode", "ContentNode")
    end if

    row = m.seasonContent.createChild("ContentNode")
    seasonTitle = "Season"
    if season <> invalid then
        seasonTitle = asString(season.title)
        if seasonTitle = "" then seasonTitle = "Season"
    end if
    row.title = seasonTitle

    for each ep in episodes
        child = row.createChild("ContentNode")
        child.title = formatEpisodeTitle(ep)
        child.hdPosterUrl = ep.hdPosterUrl
        child.description = ep.description
        child.addFields({
            ratingKey: ep.ratingKey,
            key: ep.key,
            mediaType: ep.mediaType,
            duration: ep.duration,
            viewOffset: ep.viewOffset,
            year: ep.year,
            hdBackdropUrl: ep.hdBackdropUrl,
            shortTitle: ep.shortTitle,
            index: ep.index
        })
    end for

    ' Re-assign so RowList picks up the new row in simulators that need it
    m.seasonRows.content = m.seasonContent
end sub

function formatEpisodeTitle(ep as Object) as String
    title = asString(ep.shortTitle)
    if title = "" then title = asString(ep.title)
    if title = "" then title = "Episode"
    epNo = asString(ep.index)
    if epNo <> "" then return epNo + ". " + title
    return title
end function

sub onEpisodeSelected()
    info = m.seasonRows.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.seasonRows.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return

    m.top.playRequested = {
        title: item.title,
        description: item.description,
        year: item.year,
        mediaType: item.mediaType,
        ratingKey: item.ratingKey,
        key: item.key,
        hdPosterUrl: item.hdPosterUrl,
        hdBackdropUrl: item.hdBackdropUrl,
        duration: item.duration,
        viewOffset: item.viewOffset
    }
end sub

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

sub updateMovieButtonFocus()
    if m.focusIndex = 0 then
        m.playBg.color = "0xE50914"
        m.backBg.color = "0x2A2A2A"
    else
        m.playBg.color = "0x2A2A2A"
        m.backBg.color = "0xE50914"
    end if
end sub

sub requestMoviePlay()
    item = m.top.content
    if item = invalid then return
    m.top.playRequested = item
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.isShow then
        if key = "back"
            m.top.closed = true
            return true
        end if
        return false
    end if

    if key = "left" or key = "right"
        if m.focusIndex = 0 then
            m.focusIndex = 1
        else
            m.focusIndex = 0
        end if
        updateMovieButtonFocus()
        return true
    else if key = "OK"
        if m.focusIndex = 0 then
            requestMoviePlay()
        else
            m.top.closed = true
        end if
        return true
    else if key = "play"
        requestMoviePlay()
        return true
    else if key = "back"
        m.top.closed = true
        return true
    end if

    return false
end function

function titleCaseType(mediaType as String) as String
    if mediaType = "movie" then return "Movie"
    if mediaType = "show" then return "Series"
    if mediaType = "episode" then return "Episode"
    if mediaType = "season" then return "Season"
    if Len(mediaType) = 0 then return ""
    return UCase(Left(mediaType, 1)) + Right(mediaType, Len(mediaType) - 1)
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

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function
