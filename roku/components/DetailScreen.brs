sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.statusLabel = m.top.findNode("statusLabel")

    m.movieActions = m.top.findNode("movieActions")
    m.playBtn = m.top.findNode("playBtn")
    m.backBtn = m.top.findNode("backBtn")
    m.playBg = m.top.findNode("playBg")
    m.backBg = m.top.findNode("backBg")
    m.playLabel = m.top.findNode("playLabel")

    m.tvPanel = m.top.findNode("tvPanel")
    m.seasonList = m.top.findNode("seasonList")
    m.episodeList = m.top.findNode("episodeList")
    m.episodeHeading = m.top.findNode("episodeHeading")

    m.seasonList.observeField("itemFocused", "onSeasonFocused")
    m.seasonList.observeField("itemSelected", "onSeasonSelected")
    m.episodeList.observeField("itemSelected", "onEpisodeSelected")

    m.focusIndex = 0 ' movie mode: 0 play, 1 back
    m.isShow = false
    m.tvFocus = "seasons" ' seasons | episodes
    m.seasons = []
    m.episodes = []
    m.selectedSeason = invalid
    m.selectedEpisode = invalid

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
        m.movieActions.visible = false
        m.tvPanel.visible = true
        m.statusLabel.text = "Loading seasons..."
        loadChildren(item, "seasons")
    else if mediaType = "season" then
        m.movieActions.visible = false
        m.tvPanel.visible = true
        m.seasons = [item]
        m.selectedSeason = item
        m.seasonList.content = buildListContent(m.seasons, "season")
        m.seasonList.jumpToItem = 0
        m.tvFocus = "episodes"
        m.statusLabel.text = "Loading episodes..."
        loadChildren(item, "episodes")
        m.episodeList.setFocus(true)
    else
        m.movieActions.visible = true
        m.tvPanel.visible = false
        m.playLabel.text = "Play"
        m.statusLabel.text = "OK to play  ·  Back to return"
    end if
end sub

sub loadChildren(item as Object, mode as String)
    m.loadMode = mode
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
        err = "Could not load list"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    items = response.items
    if items = invalid then items = []

    if m.loadMode = "seasons" then
        m.seasons = items
        m.seasonList.content = buildListContent(items, "season")
        if items.count() > 0 then
            m.seasonList.jumpToItem = 0
            m.selectedSeason = items[0]
            m.tvFocus = "seasons"
            m.seasonList.setFocus(true)
            m.statusLabel.text = "Select a season, then an episode"
            loadChildren(items[0], "episodes")
        else
            m.statusLabel.text = "No seasons found"
        end if
    else if m.loadMode = "episodes" then
        m.episodes = items
        m.episodeList.content = buildListContent(items, "episode")
        seasonTitle = ""
        if m.selectedSeason <> invalid then seasonTitle = asString(m.selectedSeason.title)
        m.episodeHeading.text = "Episodes"
        if seasonTitle <> "" then m.episodeHeading.text = seasonTitle + " · Episodes"
        if items.count() > 0 then
            m.episodeList.jumpToItem = 0
            m.selectedEpisode = items[0]
            m.statusLabel.text = safeCount(items.count()) + " episodes — OK to play"
        else
            m.selectedEpisode = invalid
            m.statusLabel.text = "No episodes in this season"
        end if
    end if
end sub

function buildListContent(items as Object, kind as String) as Object
    root = createObject("roSGNode", "ContentNode")
    for each item in items
        child = root.createChild("ContentNode")
        child.title = formatListTitle(item, kind)
        child.addFields({
            ratingKey: item.ratingKey,
            key: item.key,
            mediaType: item.mediaType,
            description: item.description,
            hdPosterUrl: item.hdPosterUrl,
            hdBackdropUrl: item.hdBackdropUrl,
            duration: item.duration,
            viewOffset: item.viewOffset,
            year: item.year,
            rawTitle: item.title
        })
    end for
    return root
end function

function formatListTitle(item as Object, kind as String) as String
    if kind = "season" then
        title = asString(item.title)
        if title = "" then title = "Season"
        return title
    end if

    title = asString(item.shortTitle)
    if title = "" then title = asString(item.title)
    if title = "" then title = "Episode"

    epNo = asString(item.index)
    label = title
    if epNo <> "" then label = epNo + ". " + title
    if item.viewOffset <> invalid and item.viewOffset > 0 then label = label + "  ·  Resume"
    return label
end function

sub onSeasonFocused()
    idx = m.seasonList.itemFocused
    if idx = invalid or idx < 0 or idx >= m.seasons.count() then return
    season = m.seasons[idx]
    if season = invalid then return
    if m.selectedSeason <> invalid and asString(m.selectedSeason.ratingKey) = asString(season.ratingKey) then return
    m.selectedSeason = season
    m.statusLabel.text = "Loading episodes..."
    loadChildren(season, "episodes")
end sub

sub onSeasonSelected()
    ' Move into episode list on OK
    if m.episodes.count() > 0 then
        m.tvFocus = "episodes"
        m.episodeList.setFocus(true)
    end if
end sub

sub onEpisodeSelected()
    idx = m.episodeList.itemSelected
    if idx = invalid or idx < 0 or idx >= m.episodes.count() then return
    m.selectedEpisode = m.episodes[idx]
    playEpisode(m.selectedEpisode)
end sub

sub playEpisode(episode as Object)
    if episode = invalid then return
    m.top.playRequested = episode
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
        return handleTvKeys(key)
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

function handleTvKeys(key as String) as Boolean
    if key = "back"
        m.top.closed = true
        return true
    else if key = "right"
        if m.tvFocus = "seasons" and m.episodes.count() > 0 then
            m.tvFocus = "episodes"
            m.episodeList.setFocus(true)
            return true
        end if
    else if key = "left"
        if m.tvFocus = "episodes" then
            m.tvFocus = "seasons"
            m.seasonList.setFocus(true)
            return true
        end if
    else if key = "play"
        idx = m.episodeList.itemFocused
        if idx <> invalid and idx >= 0 and idx < m.episodes.count() then
            playEpisode(m.episodes[idx])
            return true
        end if
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

function safeCount(value as Dynamic) as String
    return asString(value)
end function

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function
