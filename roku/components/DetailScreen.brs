sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")

    m.movieActions = m.top.findNode("movieActions")
    m.playBtn = m.top.findNode("playBtn")
    m.backBtn = m.top.findNode("backBtn")
    m.randomBtn = m.top.findNode("randomBtn")
    m.playBg = m.top.findNode("playBg")
    m.backBg = m.top.findNode("backBg")
    m.randomBg = m.top.findNode("randomBg")
    m.playLabel = m.top.findNode("playLabel")
    m.unavailablePanel = m.top.findNode("unavailablePanel")
    m.unavailableBody = m.top.findNode("unavailableBody")

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
    m.isUnavailable = false
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

    m.isUnavailable = false
    if item.DoesExist("isDiscover") and item.isDiscover = true then m.isUnavailable = true
    if item.DoesExist("unavailable") and item.unavailable = true then m.isUnavailable = true

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

    if m.isUnavailable then
        showUnavailableMode(item)
        loadUnavailableDetail(item)
    else if mediaType = "show" then
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

    refreshPlayLabel(item)
end sub

sub refreshPlayLabel(item as Object)
    if m.isUnavailable = true then return
    if m.playLabel = invalid or item = invalid then return

    resume = false
    mediaType = asString(item.mediaType)
    if mediaType = "show" or mediaType = "season" then
        leaves = asInteger(item.leafCount)
        viewed = asInteger(item.viewedLeafCount)
        resume = (viewed > 0 and viewed < leaves)
    else
        resume = (asInteger(item.viewOffset) > 0)
    end if

    if resume then m.playLabel.text = "Resume" else m.playLabel.text = "Play"
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
    watchBit = watchedSummary(item)
    if watchBit <> "" then metaBits.push(watchBit)
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
    m.isUnavailable = false
    m.movieActions.visible = true
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = false
    if m.playBtn <> invalid then m.playBtn.visible = true
    if m.backBtn <> invalid then m.backBtn.translation = [248, 0]
    if m.randomBtn <> invalid then m.randomBtn.visible = true
    m.movieActions.translation = [248, 240]
    if m.softStatus <> invalid then m.softStatus.translation = [248, 346]
    if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 400]
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
    m.isUnavailable = false
    m.movieActions.visible = true
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = false
    if m.playBtn <> invalid then m.playBtn.visible = true
    if m.backBtn <> invalid then m.backBtn.translation = [248, 0]
    if m.randomBtn <> invalid then m.randomBtn.visible = false
    m.movieActions.translation = [248, 240]
    if m.softStatus <> invalid then m.softStatus.translation = [248, 346]
    if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 400]
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

sub showUnavailableMode(item as Object)
    m.isUnavailable = true
    m.isShow = false
    m.tvPanel.visible = false
    m.relatedPanel.visible = false
    m.movieActions.visible = true
    if m.playBtn <> invalid then m.playBtn.visible = false
    if m.randomBtn <> invalid then m.randomBtn.visible = false
    if m.backBtn <> invalid then m.backBtn.translation = [0, 0]
    m.movieActions.translation = [248, 348]
    if m.softStatus <> invalid then m.softStatus.translation = [248, 420]
    if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 450]
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = true

    if m.unavailableBody <> invalid then m.unavailableBody.text = unavailableMessage(item)
    if m.softStatus <> invalid then m.softStatus.text = "Looking up details & similar titles…"

    m.relatedContent = createObject("roSGNode", "ContentNode")
    m.relatedRows.content = m.relatedContent
    m.focusIndex = 1
    updateMovieButtonFocus()
    m.top.setFocus(true)
end sub

function unavailableMessage(item as Object) as String
    mt = ""
    if item <> invalid then mt = asString(item.mediaType)
    if mt = "show" or mt = "series" or mt = "tv" then
        return "We don't have this show yet — but we can get it soon."
    else if mt = "movie" then
        return "We don't have this movie yet — but we can get it soon."
    end if
    return "We don't have this one yet — but we can get it soon."
end function

sub loadUnavailableDetail(item as Object)
    if m.softStatus <> invalid then m.softStatus.text = "Looking up details & similar titles…"
    m.extrasTask = createObject("roSGNode", "PlexTask")
    m.extrasTask.config = m.top.config
    m.extrasTask.action = "unavailableDetail"
    m.extrasTask.item = item
    m.extrasTask.observeField("response", "onUnavailableLoaded")
    m.extrasTask.control = "RUN"
end sub

sub onUnavailableLoaded()
    response = m.extrasTask.response
    if m.softStatus <> invalid then m.softStatus.text = ""
    if response = invalid or response.ok <> true then
        if m.softStatus <> invalid then m.softStatus.text = "Couldn't load extra details — try similar picks below if any"
        return
    end if

    detail = response.detail
    if detail <> invalid then
        applyShowHeader(detail)
        if asString(detail.hdPosterUrl) <> "" then m.poster.uri = detail.hdPosterUrl
        if asString(detail.hdBackdropUrl) <> "" then m.backdrop.uri = detail.hdBackdropUrl
        rememberShowHeader()
        if m.unavailableBody <> invalid then m.unavailableBody.text = unavailableMessage(detail)
    end if

    castItems = response.cast
    similarItems = response.similar
    if castItems = invalid then castItems = []
    if similarItems = invalid then similarItems = []

    if m.relatedContent = invalid then
        m.relatedContent = createObject("roSGNode", "ContentNode")
    end if
    while m.relatedContent.getChildCount() > 0
        m.relatedContent.removeChildIndex(0)
    end while

    if similarItems.count() > 0 then
        appendItemsRow(m.relatedContent, "In your library", similarItems)
    end if
    if castItems.count() > 0 then
        appendItemsRow(m.relatedContent, "Cast", castItems)
    end if
    m.relatedRows.content = m.relatedContent
    if similarItems.count() > 0 or castItems.count() > 0 then
        m.relatedPanel.visible = true
        if m.softStatus <> invalid then
            if similarItems.count() > 0 then
                m.softStatus.text = "Similar titles already in your library ↓"
            else
                m.softStatus.text = ""
            end if
        end if
    else if m.softStatus <> invalid then
        m.softStatus.text = "No close matches in your library yet"
    end if

    m.focusIndex = 1
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
            watched: ep.watched,
            unwatchedCount: ep.unwatchedCount,
            year: ep.year,
            hdBackdropUrl: ep.hdBackdropUrl,
            shortTitle: ep.shortTitle,
            grandparentTitle: ep.grandparentTitle,
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
            watched: ep.watched,
            unwatchedCount: ep.unwatchedCount,
            year: ep.year,
            hdBackdropUrl: ep.hdBackdropUrl,
            shortTitle: ep.shortTitle,
            grandparentTitle: ep.grandparentTitle,
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
        if asString(detail.hdPosterUrl) <> "" then m.poster.uri = detail.hdPosterUrl
        ' Always refresh the cached show synopsis; only paint it if we aren't
        ' currently previewing a focused episode.
        prevMode = m.headerMode
        applyShowHeader(detail)
        if asString(detail.hdBackdropUrl) <> "" then m.backdrop.uri = detail.hdBackdropUrl
        rememberShowHeader()
        refreshPlayLabel(detail)
        if prevMode = "episode" then
            ' Re-apply episode copy after the show cache refresh
            info = invalid
            if m.seasonRows <> invalid then info = m.seasonRows.rowItemFocused
            if info <> invalid and info.count() >= 2 and m.seasonRows.content <> invalid then
                row = m.seasonRows.content.getChild(info[0])
                if row <> invalid then
                    ep = row.getChild(info[1])
                    if ep <> invalid and asString(ep.mediaType) = "episode" then
                        applyEpisodeHeader(ep)
                    end if
                end if
            end if
        end if
    end if

    adoptOnDeck(response, detail)

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

sub adoptOnDeck(response as Object, detail as Object)
    ' Arriving from Continue Watching already pins an episode; otherwise let the
    ' server's next-up pick it, but only once there is progress worth resuming
    if m.focusEpisodeKey <> "" or detail = invalid then return
    onDeckKey = asString(response.onDeckKey)
    if onDeckKey = "" then return
    if asInteger(detail.viewedLeafCount) <= 0 then return

    m.focusEpisodeKey = onDeckKey
    m.focusSeasonKey = asString(response.onDeckSeasonKey)
    if m.seasonContent = invalid then return

    ' Season rows may already be built, and those only try to focus as they fill
    for i = 0 to m.seasonContent.getChildCount() - 1
        maybeFocusEpisode(i)
    end for
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
            watched: item.watched,
            unwatchedCount: item.unwatchedCount,
            viewedLeafCount: item.viewedLeafCount,
            leafCount: item.leafCount,
            year: item.year,
            hdBackdropUrl: item.hdBackdropUrl,
            contentRating: item.contentRating,
            rating: item.rating,
            personId: item.personId,
            shortTitle: item.shortTitle
        })
    end for
end sub

function watchedSummary(item as Object) as String
    if item = invalid then return ""

    mediaType = asString(item.mediaType)
    if mediaType = "show" or mediaType = "season" then
        leaves = asInteger(item.leafCount)
        if leaves <= 0 then return ""
        viewed = asInteger(item.viewedLeafCount)
        if viewed >= leaves then return "Watched"
        if viewed <= 0 then return ""
        return asString(viewed) + " of " + asString(leaves) + " watched"
    end if

    if asInteger(item.viewOffset) > 0 then
        return minutesLeftLabel(asInteger(item.duration) - asInteger(item.viewOffset))
    end if
    if item.watched = true then return "Watched"
    return ""
end function

function minutesLeftLabel(remainingMs as Integer) as String
    if remainingMs <= 0 then return ""
    minutes = Int(remainingMs / 60000)
    if minutes < 1 then return "Almost finished"
    return asString(minutes) + " min left"
end function

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
    isDiscover = false
    if item.DoesExist("isDiscover") and item.isDiscover = true then isDiscover = true
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
        watched: item.watched,
        unwatchedCount: item.unwatchedCount,
        viewedLeafCount: item.viewedLeafCount,
        leafCount: item.leafCount,
        personId: item.personId,
        shortTitle: item.shortTitle,
        grandparentTitle: item.grandparentTitle,
        index: item.index,
        parentIndex: item.parentIndex,
        isDiscover: isDiscover
    }
end function

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end sub

sub updateMovieButtonFocus()
    if m.isUnavailable = true then
        ' Only Back is actionable
        m.focusIndex = 1
        m.playBg.color = "0x2A2A32"
        m.backBg.color = "0xE50914"
        if m.randomBg <> invalid then m.randomBg.color = "0x2A2A32"
        if m.top.findNode("playShadow") <> invalid then m.top.findNode("playShadow").opacity = 0.0
        if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.5
        if m.top.findNode("randomShadow") <> invalid then m.top.findNode("randomShadow").opacity = 0.0
        return
    end if

    m.playBg.color = "0x2A2A32"
    m.backBg.color = "0x2A2A32"
    if m.randomBg <> invalid then m.randomBg.color = "0x2A2A32"
    if m.top.findNode("playShadow") <> invalid then m.top.findNode("playShadow").opacity = 0.0
    if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.0
    if m.top.findNode("randomShadow") <> invalid then m.top.findNode("randomShadow").opacity = 0.0

    if m.focusIndex = 0 then
        m.playBg.color = "0xE50914"
        if m.top.findNode("playShadow") <> invalid then m.top.findNode("playShadow").opacity = 0.5
    else if m.focusIndex = 1 then
        m.backBg.color = "0xE50914"
        if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.5
    else
        if m.randomBg <> invalid then m.randomBg.color = "0xE50914"
        if m.top.findNode("randomShadow") <> invalid then m.top.findNode("randomShadow").opacity = 0.5
    end if
end sub

function actionButtonCount() as Integer
    if m.isUnavailable = true then return 2
    if m.isShow = true and m.randomBtn <> invalid and m.randomBtn.visible = true then return 3
    return 2
end function

sub focusActionButtons()
    m.focusIndex = 0
    updateMovieButtonFocus()
    ' Drop shelf focus so cast/episode rings cannot linger while Play is active
    if m.relatedRows <> invalid then
        m.relatedRows.setFocus(false)
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
    if m.isUnavailable = true then return
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

sub requestRandomEpisode()
    if m.isUnavailable = true then return
    if m.isShow <> true then return
    item = m.top.content
    if item = invalid then return

    if m.softStatus <> invalid then m.softStatus.text = "Picking a random episode…"
    m.randomTask = createObject("roSGNode", "PlexTask")
    m.randomTask.config = m.top.config
    m.randomTask.action = "randomEpisode"
    m.randomTask.item = item
    m.randomTask.observeField("response", "onRandomEpisodeReady")
    m.randomTask.control = "RUN"
end sub

sub onRandomEpisodeReady()
    response = m.randomTask.response
    if m.softStatus <> invalid then m.softStatus.text = ""
    if response = invalid or response.ok <> true or response.item = invalid then
        err = "Couldn't pick a random episode"
        if response <> invalid and response.error <> invalid then err = response.error
        if m.softStatus <> invalid then m.softStatus.text = err
        return
    end if
    m.top.playRequested = response.item
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        m.top.closed = true
        return true
    end if

    ' Shared Play / Back / Random button row (movies + shows)
    if m.relatedRows.hasFocus() or m.seasonRows.hasFocus() then
        return false
    end if

    if key = "left" or key = "right"
        if m.isUnavailable = true then return true
        count = actionButtonCount()
        if key = "right" then
            m.focusIndex = m.focusIndex + 1
            if m.focusIndex >= count then m.focusIndex = 0
        else
            m.focusIndex = m.focusIndex - 1
            if m.focusIndex < 0 then m.focusIndex = count - 1
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
        if m.isUnavailable = true then
            m.top.closed = true
            return true
        end if
        if m.focusIndex = 0 then
            requestMoviePlay()
        else if m.focusIndex = 1 then
            m.top.closed = true
        else
            requestRandomEpisode()
        end if
        return true
    else if key = "play"
        if m.isUnavailable = true then return true
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

function asInteger(value as Dynamic) as Integer
    if value = invalid then return 0
    valueType = type(value)
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return value
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        return Int(value)
    end if
    if valueType = "String" or valueType = "roString" then
        if value = "" then return 0
        return Int(Val(value))
    end if
    return 0
end function

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function
