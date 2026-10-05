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

    m.relatedPanel = m.top.findNode("relatedPanel")
    m.relatedRows = m.top.findNode("relatedRows")
    m.relatedRows.observeField("rowItemSelected", "onRelatedSelected")

    m.focusIndex = 0
    m.isShow = false
    m.seasons = []
    m.seasonQueue = 0
    m.seasonContent = invalid
    m.pendingSeason = invalid
    m.relatedContent = invalid
    m.prefetchAhead = 2

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
        loadExtras(item)
    else if mediaType = "season" then
        showTvMode()
        m.seasons = [item]
        m.seasonQueue = 0
        m.seasonContent = createObject("roSGNode", "ContentNode")
        m.seasonRows.content = m.seasonContent
        loadSeasonEpisodes()
        loadExtras(item)
    else
        showMovieMode()
        loadExtras(item)
    end if
end sub

sub showTvMode()
    m.movieActions.visible = false
    m.relatedPanel.visible = false
    m.tvPanel.visible = true
    m.poster.width = 200
    m.poster.height = 300
    m.poster.translation = [80, 48]
    m.titleLabel.translation = [320, 56]
    m.metaLabel.translation = [320, 136]
    m.summaryLabel.translation = [320, 180]
    m.summaryLabel.height = 80
    m.summaryLabel.maxLines = 2
end sub

sub showMovieMode()
    m.movieActions.visible = true
    m.tvPanel.visible = false
    m.relatedPanel.visible = true
    m.playLabel.text = "Play"
    m.poster.width = 260
    m.poster.height = 390
    m.poster.translation = [80, 56]
    m.titleLabel.translation = [400, 64]
    m.metaLabel.translation = [400, 144]
    m.summaryLabel.translation = [400, 190]
    m.summaryLabel.height = 96
    m.summaryLabel.maxLines = 3
    m.relatedContent = createObject("roSGNode", "ContentNode")
    m.relatedRows.content = m.relatedContent
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

sub loadExtras(item as Object)
    m.extrasTask = createObject("roSGNode", "PlexTask")
    m.extrasTask.config = m.top.config
    m.extrasTask.action = "extras"
    m.extrasTask.item = item
    m.extrasTask.observeField("response", "onExtrasLoaded")
    m.extrasTask.control = "RUN"
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
        ' Create empty labeled season rows immediately so rails appear early
        for each season in items
            row = m.seasonContent.createChild("ContentNode")
            title = asString(season.title)
            if title = "" then title = "Season"
            row.title = title
        end for
        m.seasonRows.content = m.seasonContent
        if items.count() = 0 then return
        ' Prefetch first few seasons right away
        loadSeasonEpisodes()
    else if m.loadMode = "episodes" then
        fillSeasonRow(m.seasonQueue, m.pendingSeason, items)
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

sub fillSeasonRow(index as Integer, season as Object, episodes as Object)
    if m.seasonContent = invalid then return
    if index < 0 or index >= m.seasonContent.getChildCount() then
        appendSeasonRow(season, episodes)
        return
    end if

    row = m.seasonContent.getChild(index)
    while row.getChildCount() > 0
        row.removeChildIndex(0)
    end while

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

    m.seasonRows.content = m.seasonContent
    if index = 0 then m.seasonRows.setFocus(true)
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

    m.seasonRows.content = m.seasonContent
end sub

sub onExtrasLoaded()
    response = m.extrasTask.response
    if response = invalid or response.ok <> true then return

    castItems = response.cast
    similarItems = response.similar
    if castItems = invalid then castItems = []
    if similarItems = invalid then similarItems = []

    if m.isShow then
        ' Append extras under season rails once seasons exist
        if m.seasonContent = invalid then
            m.seasonContent = createObject("roSGNode", "ContentNode")
        end if
        appendItemsRow(m.seasonContent, "Cast", castItems)
        appendItemsRow(m.seasonContent, "More Like This", similarItems)
        m.seasonRows.content = m.seasonContent
    else
        if m.relatedContent = invalid then
            m.relatedContent = createObject("roSGNode", "ContentNode")
        end if
        appendItemsRow(m.relatedContent, "Cast", castItems)
        appendItemsRow(m.relatedContent, "More Like This", similarItems)
        m.relatedRows.content = m.relatedContent
        m.relatedPanel.visible = true
    end if
end sub

sub appendItemsRow(root as Object, title as String, items as Object)
    if items = invalid or items.count() = 0 then return
    row = root.createChild("ContentNode")
    row.title = title
    for each item in items
        child = row.createChild("ContentNode")
        child.title = asString(item.title)
        child.hdPosterUrl = item.hdPosterUrl
        child.description = item.description
        child.addFields({
            ratingKey: item.ratingKey,
            key: item.key,
            mediaType: item.mediaType,
            duration: item.duration,
            viewOffset: item.viewOffset,
            year: item.year,
            hdBackdropUrl: item.hdBackdropUrl,
            contentRating: item.contentRating,
            rating: item.rating
        })
    end for
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

    mediaType = asString(item.mediaType)
    if mediaType = "actor" then return
    if mediaType = "episode" then
        m.top.playRequested = nodeToItem(item)
    else if mediaType = "movie" or mediaType = "show" then
        m.top.openDetails = nodeToItem(item)
    end if
end sub

sub onRelatedSelected()
    info = m.relatedRows.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.relatedRows.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return

    mediaType = asString(item.mediaType)
    if mediaType = "actor" then return
    m.top.openDetails = nodeToItem(item)
end sub

function nodeToItem(item as Object) as Object
    return {
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
end function

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
        else if key = "down" and m.movieActions.visible = false
            if not m.seasonRows.hasFocus() then
                m.seasonRows.setFocus(true)
                return true
            end if
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
    else if key = "down"
        if m.relatedPanel.visible = true then
            m.relatedRows.setFocus(true)
            return true
        end if
    else if key = "up"
        if m.relatedRows.hasFocus() then
            updateMovieButtonFocus()
            m.top.setFocus(true)
            return true
        end if
    else if key = "OK"
        if m.relatedRows.hasFocus() then return false
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
