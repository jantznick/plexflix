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
    m.seasonRows.observeField("rowItemFocused", "onSeasonItemFocused")
    m.seasonRows.observeField("escapeUp", "onSeasonEscapeUp")
    m.seasonRows.observeField("escapeBack", "onEscapeBack")

    m.relatedPanel = m.top.findNode("relatedPanel")
    m.relatedRows = m.top.findNode("relatedRows")
    m.relatedRows.observeField("rowItemSelected", "onRelatedSelected")
    m.relatedRows.observeField("escapeUp", "onRelatedEscapeUp")
    m.relatedRows.observeField("escapeBack", "onEscapeBack")
    m.softStatus = m.top.findNode("softStatus")

    m.focusIndex = 0
    m.isShow = false
    m.seasons = []
    m.seasonQueue = 0
    m.seasonContent = invalid
    m.pendingSeason = invalid
    m.relatedContent = invalid
    m.focusEpisodeKey = ""
    m.focusSeasonKey = ""
    m.showHeader = invalid
    m.headerMode = "show"

    updateMovieButtonFocus()
end sub

sub onContentSet()
    item = m.top.content
    if item = invalid then return

    m.focusEpisodeKey = asString(item.focusEpisodeKey)
    m.focusSeasonKey = asString(item.focusSeasonKey)

    applyShowHeader(item)
    rememberShowHeader()

    if item.hdBackdropUrl <> invalid and item.hdBackdropUrl <> "" then
        m.backdrop.uri = item.hdBackdropUrl
    end if
    if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
        m.poster.uri = item.hdPosterUrl
    end if

    mediaType = asString(item.mediaType)
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

sub applyShowHeader(item as Object)
    if item = invalid then return
    m.titleLabel.text = asString(item.title)
    m.summaryLabel.text = asString(item.description)
    if m.softStatus <> invalid then m.softStatus.text = ""

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
    m.headerMode = "show"
end sub

sub rememberShowHeader()
    m.showHeader = {
        title: m.titleLabel.text,
        meta: m.metaLabel.text,
        summary: m.summaryLabel.text,
        backdrop: ""
    }
    if m.backdrop <> invalid and m.backdrop.uri <> invalid then
        m.showHeader.backdrop = m.backdrop.uri
    end if
end sub

sub restoreShowHeader()
    if m.showHeader = invalid then return
    m.titleLabel.text = asString(m.showHeader.title)
    m.metaLabel.text = asString(m.showHeader.meta)
    m.summaryLabel.text = asString(m.showHeader.summary)
    if asString(m.showHeader.backdrop) <> "" and m.backdrop <> invalid then
        m.backdrop.uri = m.showHeader.backdrop
    end if
    m.headerMode = "show"
end sub

sub applyEpisodeHeader(ep as Object)
    if ep = invalid then return

    epTitle = asString(ep.shortTitle)
    if epTitle = "" then epTitle = asString(ep.title)
    showTitle = ""
    if m.showHeader <> invalid then showTitle = asString(m.showHeader.title)
    if showTitle = "" and m.top.content <> invalid then showTitle = asString(m.top.content.title)

    seasonNo = asString(ep.parentIndex)
    epNo = asString(ep.index)
    headline = epTitle
    if showTitle <> "" and epTitle <> "" then
        if seasonNo <> "" and epNo <> "" then
            headline = showTitle + " — S" + seasonNo + "E" + epNo + " " + epTitle
        else
            headline = showTitle + " — " + epTitle
        end if
    end if
    m.titleLabel.text = headline

    metaBits = []
    year = asString(ep.year)
    if year <> "" then metaBits.push(year)
    if m.top.content <> invalid then
        contentRating = asString(m.top.content.contentRating)
        if contentRating <> "" then metaBits.push(contentRating)
    end if
    if seasonNo <> "" and epNo <> "" then
        metaBits.push("S" + seasonNo + " · E" + epNo)
    end if
    metaBits.push("Episode")
    m.metaLabel.text = joinStrings(metaBits, "  ·  ")

    summary = asString(ep.description)
    if summary = "" and m.showHeader <> invalid then summary = asString(m.showHeader.summary)
    m.summaryLabel.text = summary

    if asString(ep.hdBackdropUrl) <> "" and m.backdrop <> invalid then
        m.backdrop.uri = ep.hdBackdropUrl
    end if
    m.headerMode = "episode"
end sub

sub onSeasonItemFocused()
    info = m.seasonRows.rowItemFocused
    if info = invalid or info.count() < 2 then return
    if m.seasonRows.content = invalid then return
    row = m.seasonRows.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return

    mediaType = asString(item.mediaType)
    if mediaType = "episode" then
        applyEpisodeHeader(item)
    else
        ' Cast / other rows under the same list — show synopsis again
        restoreShowHeader()
    end if
end sub

sub showTvMode()
    m.movieActions.visible = true
    m.relatedPanel.visible = false
    m.tvPanel.visible = true
    m.playLabel.text = "Play"
    m.poster.width = 210
    m.poster.height = 315
    m.poster.translation = [0, 0]
    m.titleLabel.translation = [248, 12]
    m.metaLabel.translation = [248, 92]
    m.summaryLabel.translation = [248, 136]
    m.summaryLabel.height = 88
    m.focusIndex = 0
    updateMovieButtonFocus()
end sub

sub showMovieMode()
    m.movieActions.visible = true
    m.tvPanel.visible = false
    m.relatedPanel.visible = false
    m.playLabel.text = "Play"
    m.poster.width = 210
    m.poster.height = 315
    m.poster.translation = [0, 0]
    m.titleLabel.translation = [248, 12]
    m.metaLabel.translation = [248, 92]
    m.summaryLabel.translation = [248, 136]
    m.summaryLabel.height = 88
    m.relatedContent = createObject("roSGNode", "ContentNode")
    m.relatedRows.content = m.relatedContent
    m.focusIndex = 0
    updateMovieButtonFocus()
    m.top.setFocus(true)
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
    if m.softStatus <> invalid then m.softStatus.text = "Loading related..."
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
        ' Prefer the Continue Watching season first so focus lands sooner
        prioritizeFocusSeason()
        if m.focusEpisodeKey <> "" then m.seasonRows.setFocus(true)
        loadSeasonEpisodes()
    else if m.loadMode = "episodes" then
        fillSeasonRow(m.seasonQueue, m.pendingSeason, items)
        m.seasonQueue = m.seasonQueue + 1
        loadSeasonEpisodes()
    end if
end sub

sub prioritizeFocusSeason()
    if m.focusSeasonKey = "" or m.seasons = invalid then return
    target = -1
    for i = 0 to m.seasons.count() - 1
        if asString(m.seasons[i].ratingKey) = m.focusSeasonKey then
            target = i
            exit for
        end if
    end for
    if target <= 0 then return

    ' Rotate so the focus season is loaded first, then wrap around
    reordered = []
    for i = target to m.seasons.count() - 1
        reordered.push(m.seasons[i])
    end for
    for i = 0 to target - 1
        reordered.push(m.seasons[i])
    end for
    m.seasons = reordered

    ' Keep ContentNode row titles aligned with the new order
    if m.seasonContent = invalid then return
    while m.seasonContent.getChildCount() > 0
        m.seasonContent.removeChildIndex(0)
    end while
    for each season in m.seasons
        row = m.seasonContent.createChild("ContentNode")
        title = asString(season.title)
        if title = "" then title = "Season"
        row.title = title
    end for
    m.seasonRows.content = m.seasonContent
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
            index: ep.index,
            parentIndex: ep.parentIndex
        })
    end for

    m.seasonRows.content = m.seasonContent
    maybeFocusEpisode(index)
end sub

sub maybeFocusEpisode(seasonIndex as Integer)
    if m.focusEpisodeKey = "" then return
    if m.seasonContent = invalid then return
    if seasonIndex < 0 or seasonIndex >= m.seasonContent.getChildCount() then return

    season = m.seasons[seasonIndex]
    if m.focusSeasonKey <> "" and season <> invalid then
        if asString(season.ratingKey) <> m.focusSeasonKey then return
    end if

    row = m.seasonContent.getChild(seasonIndex)
    if row = invalid then return
    epIndex = 0
    found = false
    count = row.getChildCount()
    for i = 0 to count - 1
        child = row.getChild(i)
        if child <> invalid and asString(child.ratingKey) = m.focusEpisodeKey then
            epIndex = i
            found = true
            exit for
        end if
    end for
    if not found and m.focusSeasonKey = "" then return

    m.seasonRows.jumpToRowItem = [seasonIndex, epIndex]
    m.seasonRows.setFocus(true)
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
            index: ep.index,
            parentIndex: ep.parentIndex
        })
    end for

    m.seasonRows.content = m.seasonContent
end sub

sub onExtrasLoaded()
    response = m.extrasTask.response
    if m.softStatus <> invalid then m.softStatus.text = ""
    if response = invalid or response.ok <> true then return

    ' Enrich header from full metadata (important when opened from Continue Watching episode)
    detail = response.detail
    if detail <> invalid then
        applyShowHeader(detail)
        if asString(detail.hdPosterUrl) <> "" then m.poster.uri = detail.hdPosterUrl
        if asString(detail.hdBackdropUrl) <> "" then m.backdrop.uri = detail.hdBackdropUrl
        rememberShowHeader()
    end if

    castItems = response.cast
    similarItems = response.similar
    if castItems = invalid then castItems = []
    if similarItems = invalid then similarItems = []

    if m.isShow then
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
        if castItems.count() > 0 or similarItems.count() > 0 then
            m.relatedPanel.visible = true
        end if
        ' Keep Play focused — extras should never steal control
        if not m.relatedRows.hasFocus() then
            m.focusIndex = 0
            updateMovieButtonFocus()
            m.top.setFocus(true)
        end if
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
            rating: item.rating,
            personId: item.personId,
            shortTitle: item.shortTitle
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
    if mediaType = "actor" then
        m.top.openDetails = nodeToItem(item)
        return
    end if
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
        viewOffset: item.viewOffset,
        personId: item.personId,
        shortTitle: item.shortTitle
    }
end function

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

sub updateMovieButtonFocus()
    if m.focusIndex = 0 then
        m.playBg.color = "0xE50914"
        m.backBg.color = "0x2A2A32"
        if m.top.findNode("playShadow") <> invalid then m.top.findNode("playShadow").opacity = 0.5
        if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.0
    else
        m.playBg.color = "0x2A2A32"
        m.backBg.color = "0xE50914"
        if m.top.findNode("playShadow") <> invalid then m.top.findNode("playShadow").opacity = 0.0
        if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.5
    end if
end sub

sub focusActionButtons()
    m.focusIndex = 0
    updateMovieButtonFocus()
    ' Drop shelf focus so cast/episode rings cannot linger while Play is active
    if m.relatedRows <> invalid then
        m.relatedRows.setFocus(false)
        m.relatedRows.visible = false
        m.relatedRows.visible = true
    end if
    if m.seasonRows <> invalid then
        m.seasonRows.setFocus(false)
    end if
    m.movieActions.setFocus(true)
    m.top.setFocus(true)
end sub

sub onEscapeBack()
    m.top.closed = true
end sub

sub onRelatedEscapeUp()
    focusActionButtons()
end sub

sub onSeasonEscapeUp()
    focusActionButtons()
end sub

sub requestMoviePlay()
    item = m.top.content
    if item = invalid then return

    if m.isShow then
        ' Play focused episode if one is selected in the season rows
        if m.seasonRows <> invalid and m.seasonRows.content <> invalid then
            info = m.seasonRows.rowItemFocused
            if info <> invalid and info.count() >= 2 then
                row = m.seasonRows.content.getChild(info[0])
                if row <> invalid then
                    ep = row.getChild(info[1])
                    if ep <> invalid and asString(ep.mediaType) = "episode" then
                        m.top.playRequested = nodeToItem(ep)
                        return
                    end if
                end if
            end if
        end if
    end if

    m.top.playRequested = item
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.closed = true
        return true
    end if

    ' Shared Play / Back button row (movies + shows)
    if m.relatedRows.hasFocus() or m.seasonRows.hasFocus() then
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
        if m.isShow and m.tvPanel.visible = true then
            m.seasonRows.setFocus(true)
            return true
        else if m.relatedPanel.visible = true then
            m.relatedRows.setFocus(true)
            return true
        end if
    else if key = "up"
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
