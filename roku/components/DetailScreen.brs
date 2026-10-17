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
    m.grabBtn = m.top.findNode("grabBtn")
    m.grabBg = m.top.findNode("grabBg")
    m.grabLabel = m.top.findNode("grabLabel")
    m.watchlistBtn = m.top.findNode("watchlistBtn")
    m.watchlistBg = m.top.findNode("watchlistBg")
    m.watchlistLabel = m.top.findNode("watchlistLabel")
    m.playBg = m.top.findNode("playBg")
    m.backBg = m.top.findNode("backBg")
    m.randomBg = m.top.findNode("randomBg")
    m.playLabel = m.top.findNode("playLabel")
    m.unavailablePanel = m.top.findNode("unavailablePanel")
    m.unavailableBody = m.top.findNode("unavailableBody")
    m.grabPollTimer = m.top.findNode("grabPollTimer")
    if m.grabPollTimer <> invalid then
        m.grabPollTimer.observeField("fire", "onGrabPollFire")
    end if

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
    m.onWatchlist = false
    m.watchlistBusy = false
    m.grabJobs = {}
    m.focusGrabKey = ""
    m.grabPollIndex = 0
    m.grabCreateBusy = false
    m.showTmdbId = ""
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

    stopGrabPolling()

    m.focusEpisodeKey = asString(item.focusEpisodeKey)
    m.focusSeasonKey = asString(item.focusSeasonKey)

    m.isUnavailable = false
    m.onWatchlist = false
    m.watchlistBusy = false
    m.grabJobs = {}
    m.focusGrabKey = ""
    m.grabPollIndex = 0
    m.grabCreateBusy = false
    m.showTmdbId = ""
    if item.DoesExist("onWatchlist") and item.onWatchlist = true then m.onWatchlist = true
    if item.DoesExist("tmdbId") and asString(item.tmdbId) <> "" then m.showTmdbId = asString(item.tmdbId)
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

    ' Keep the show backdrop — episode art (and especially portrait show posters
    ' used as missing-ep stand-ins) stretch badly in the wide hero.
    if m.showHeader <> invalid and asString(m.showHeader.backdrop) <> "" and m.backdrop <> invalid then
        m.backdrop.uri = m.showHeader.backdrop
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
        m.focusGrabKey = grabKeyForEpisode(item)
        paintFocusSoftStatus()
    else
        ' Cast / other rows under the same list — show synopsis again
        m.focusGrabKey = ""
        restoreShowHeader()
        if m.softStatus <> invalid then
            ' Only clear grab/missing hints when leaving episodes
            paintFocusSoftStatus()
        end if
    end if
end sub

sub showTvMode()
    m.isUnavailable = false
    ' Keep polling if any episode grabs are still active on this page
    if grabActiveCount() = 0 then stopGrabPolling()
    m.movieActions.visible = true
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = false
    if m.grabBtn <> invalid then m.grabBtn.visible = false
    if m.watchlistBtn <> invalid then m.watchlistBtn.visible = false
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
    stopGrabPolling()
    m.movieActions.visible = true
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = false
    if m.grabBtn <> invalid then m.grabBtn.visible = false
    if m.watchlistBtn <> invalid then m.watchlistBtn.visible = false
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
    if m.watchlistBtn <> invalid then m.watchlistBtn.visible = true

    ' Fail-open: Grab Now only appears when grabUrl is configured. Empty/down
    ' server must never remove Watchlist or Back.
    showGrab = grabIsConfigured()
    if m.grabBtn <> invalid then m.grabBtn.visible = showGrab
    if showGrab = true then
        if m.grabBtn <> invalid then m.grabBtn.translation = [0, 0]
        if m.watchlistBtn <> invalid then m.watchlistBtn.translation = [240, 0]
        if m.backBtn <> invalid then m.backBtn.translation = [580, 0]
    else
        if m.watchlistBtn <> invalid then m.watchlistBtn.translation = [0, 0]
        if m.backBtn <> invalid then m.backBtn.translation = [340, 0]
    end if

    m.movieActions.translation = [248, 348]
    if m.softStatus <> invalid then m.softStatus.translation = [248, 412]
    if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 440]
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = true

    if m.unavailableBody <> invalid then m.unavailableBody.text = unavailableMessage(item)
    if m.softStatus <> invalid then m.softStatus.text = "Looking up details & similar titles…"
    paintWatchlistLabel()
    paintGrabLabel()

    m.relatedContent = createObject("roSGNode", "ContentNode")
    m.relatedRows.content = m.relatedContent
    m.focusIndex = 0
    updateMovieButtonFocus()
    m.top.setFocus(true)
end sub

sub paintWatchlistLabel()
    if m.watchlistLabel = invalid then return
    if m.onWatchlist = true then
        m.watchlistLabel.text = "Remove Watchlist"
    else
        m.watchlistLabel.text = "Add to Watchlist"
    end if
end sub

sub paintGrabLabel()
    if m.grabLabel = invalid then return
    pageJob = invalid
    if m.grabJobs <> invalid and m.grabJobs.DoesExist("page") then pageJob = m.grabJobs["page"]
    if pageJob <> invalid and pageJob.active = true then
        m.grabLabel.text = "Grabbing…"
    else
        m.grabLabel.text = "Grab Now"
    end if
end sub

function grabIsConfigured() as Boolean
    cfg = m.top.config
    if cfg = invalid then return false
    if cfg.DoesExist("grabUrl") <> true then return false
    if cfg.grabUrl = invalid then return false
    return (cfg.grabUrl + "").Trim() <> ""
end function

function grabKeyForEpisode(ep as Object) as String
    if ep = invalid then return ""
    seasonNo = asString(ep.parentIndex)
    epNo = asString(ep.index)
    if seasonNo = "" and ep.DoesExist("season") then seasonNo = asString(ep.season)
    if epNo = "" and ep.DoesExist("episode") then epNo = asString(ep.episode)
    if seasonNo = "" or epNo = "" then return ""
    return "S" + seasonNo + "E" + epNo
end function

function grabActiveCount() as Integer
    if m.grabJobs = invalid then return 0
    n = 0
    for each key in m.grabJobs
        job = m.grabJobs[key]
        if job <> invalid and job.active = true then n = n + 1
    end for
    return n
end function

function grabJobKeys() as Object
    keys = []
    if m.grabJobs = invalid then return keys
    for each key in m.grabJobs
        job = m.grabJobs[key]
        if job <> invalid and job.active = true then keys.push(key)
    end for
    return keys
end function

sub paintFocusSoftStatus()
    if m.softStatus = invalid then return

    ' Page-level unavailable grab always owns the status line on that screen
    if m.isUnavailable = true then
        pageJob = invalid
        if m.grabJobs <> invalid and m.grabJobs.DoesExist("page") then pageJob = m.grabJobs["page"]
        if pageJob <> invalid and pageJob.active = true then
            m.softStatus.text = asString(pageJob.line)
            return
        end if
    end if

    key = asString(m.focusGrabKey)
    if key <> "" and m.grabJobs <> invalid and m.grabJobs.DoesExist(key) then
        job = m.grabJobs[key]
        if job <> invalid and job.active = true then
            m.softStatus.text = asString(job.line)
            return
        end if
    end if

    ' No active grab for the focused ep — missing hint or clear
    if key <> "" then
        ep = focusedEpisodeNode()
        if ep <> invalid and ep.DoesExist("missing") and ep.missing = true then
            if grabIsConfigured() then
                m.softStatus.text = "Not in library — OK to Grab Now"
            else
                m.softStatus.text = "Not in library"
            end if
            return
        end if
    end if

    m.softStatus.text = ""
end sub

function focusedEpisodeNode() as Object
    if m.seasonRows = invalid or m.seasonRows.content = invalid then return invalid
    info = m.seasonRows.rowItemFocused
    if info = invalid or info.count() < 2 then return invalid
    row = m.seasonRows.content.getChild(info[0])
    if row = invalid then return invalid
    return row.getChild(info[1])
end function

sub setGrabJobLine(job as Object, line as String)
    if job = invalid then return
    job.line = line
    if asString(job.key) = asString(m.focusGrabKey) or (job.key = "page" and m.isUnavailable = true) then
        if m.softStatus <> invalid then m.softStatus.text = line
    end if
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
    pageJob = invalid
    if m.grabJobs <> invalid and m.grabJobs.DoesExist("page") then pageJob = m.grabJobs["page"]
    awaitingPage = (pageJob <> invalid and pageJob.active = true and pageJob.awaitingPlex = true)
    if awaitingPage <> true then
        if m.softStatus <> invalid then m.softStatus.text = "Looking up details & similar titles…"
    end if
    m.extrasTask = createObject("roSGNode", "PlexTask")
    m.extrasTask.config = m.top.config
    m.extrasTask.action = "unavailableDetail"
    m.extrasTask.item = item
    m.extrasTask.observeField("response", "onUnavailableLoaded")
    m.extrasTask.control = "RUN"
end sub

sub onUnavailableLoaded()
    response = m.extrasTask.response
    pageJob = invalid
    if m.grabJobs <> invalid and m.grabJobs.DoesExist("page") then pageJob = m.grabJobs["page"]
    if pageJob <> invalid then pageJob.findBusy = false

    ' Post-grab page flip: keep rechecking until Plex has the title
    if pageJob <> invalid and pageJob.active = true and pageJob.awaitingPlex = true then
        if response <> invalid and response.ok = true and response.localItem <> invalid then
            localItem = response.localItem
            if response.onWatchlist = true then localItem.onWatchlist = true
            finishGrabJob("page")
            if m.softStatus <> invalid then m.softStatus.text = "Ready — opening…"
            m.top.content = localItem
            return
        end if
        setGrabJobLine(pageJob, "Ready — waiting for Plex to index…")
        return
    end if

    if m.softStatus <> invalid then m.softStatus.text = ""
    if response = invalid or response.ok <> true then
        if m.softStatus <> invalid then m.softStatus.text = "Couldn't load extra details — try similar picks below if any"
        return
    end if

    ' Same plex:// guid already in the local library — promote to a normal Play page
    if response.localItem <> invalid then
        localItem = response.localItem
        if response.onWatchlist = true then localItem.onWatchlist = true
        m.top.content = localItem
        return
    end if

    if response.DoesExist("onWatchlist") then m.onWatchlist = (response.onWatchlist = true)
    paintWatchlistLabel()

    detail = response.detail
    if detail <> invalid then
        applyShowHeader(detail)
        if asString(detail.hdPosterUrl) <> "" then m.poster.uri = detail.hdPosterUrl
        if asString(detail.hdBackdropUrl) <> "" then m.backdrop.uri = detail.hdBackdropUrl
        rememberShowHeader()
        if m.unavailableBody <> invalid then m.unavailableBody.text = unavailableMessage(detail)

        ' Stamp Discover identity onto the live content object without retriggering onContentSet
        content = m.top.content
        if content <> invalid then
            if asString(detail.description) <> "" then content.description = detail.description
            if asString(detail.hdPosterUrl) <> "" then content.hdPosterUrl = detail.hdPosterUrl
            if asString(detail.hdBackdropUrl) <> "" then content.hdBackdropUrl = detail.hdBackdropUrl
            if asString(detail.year) <> "" then content.year = detail.year
            if asString(detail.rating) <> "" then content.rating = detail.rating
            if asString(detail.contentRating) <> "" then content.contentRating = detail.contentRating
            if asString(detail.mediaType) <> "" then content.mediaType = detail.mediaType
            if asString(detail.discoverRatingKey) <> "" then content.discoverRatingKey = detail.discoverRatingKey
            if asString(detail.guid) <> "" then content.guid = detail.guid
            if asString(response.discoverRatingKey) <> "" then content.discoverRatingKey = response.discoverRatingKey
            if asString(response.guid) <> "" then content.guid = response.guid
            if asString(response.tmdbId) <> "" then content.tmdbId = response.tmdbId
            content.onWatchlist = m.onWatchlist
            content.isDiscover = true
            content.unavailable = true
        end if
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

    m.focusIndex = 0
    updateMovieButtonFocus()
    m.top.setFocus(true)
end sub

sub loadChildren(item as Object, mode as String)
    m.loadMode = mode
    m.pendingSeason = item
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    if mode = "episodes" then
        show = m.top.content
        payload = {
            ratingKey: asString(item.ratingKey),
            index: asString(item.index),
            showRatingKey: "",
            showTitle: "",
            showYear: "",
            showTmdbId: m.showTmdbId,
            showPosterUrl: "",
            grandparentTitle: ""
        }
        if show <> invalid then
            payload.showRatingKey = asString(show.ratingKey)
            payload.showTitle = asString(show.title)
            payload.showYear = asString(show.year)
            payload.grandparentTitle = asString(show.title)
            payload.showPosterUrl = asString(show.hdPosterUrl)
            if payload.showPosterUrl = "" then payload.showPosterUrl = asString(show.hdShowPosterUrl)
            if m.showTmdbId = "" and show.DoesExist("tmdbId") then
                payload.showTmdbId = asString(show.tmdbId)
            end if
        end if
        m.task.action = "seasonEpisodes"
        m.task.item = payload
    else
        m.task.action = "children"
        m.task.item = item
    end if
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
        if response.DoesExist("showTmdbId") and asString(response.showTmdbId) <> "" then
            m.showTmdbId = asString(response.showTmdbId)
            content = m.top.content
            if content <> invalid then content.tmdbId = m.showTmdbId
        end if
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
        isMissing = false
        if ep.DoesExist("missing") and ep.missing = true then isMissing = true
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
            parentIndex: ep.parentIndex,
            missing: isMissing,
            tmdbId: ep.tmdbId,
            showRatingKey: ep.showRatingKey
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
        isMissing = false
        if ep.DoesExist("missing") and ep.missing = true then isMissing = true
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
            parentIndex: ep.parentIndex,
            missing: isMissing,
            tmdbId: ep.tmdbId,
            showRatingKey: ep.showRatingKey
        })
    end for

    m.seasonRows.content = m.seasonContent
end sub

sub onExtrasLoaded()
    response = m.extrasTask.response
    ' Don't leave a stale grab line if focus moved while extras were loading
    paintFocusSoftStatus()
    if response = invalid or response.ok <> true then return

    if response.DoesExist("tmdbId") and asString(response.tmdbId) <> "" then
        m.showTmdbId = asString(response.tmdbId)
        content = m.top.content
        if content <> invalid then content.tmdbId = m.showTmdbId
    end if

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
        if item.DoesExist("missing") and item.missing = true then
            requestGrabEpisode(item, info[0], info[1])
            return
        end if
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
    isMissing = false
    if item.DoesExist("missing") and item.missing = true then isMissing = true
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
        isDiscover: isDiscover,
        missing: isMissing,
        tmdbId: item.tmdbId,
        showRatingKey: item.showRatingKey
    }
end function

sub onCloseRequested()
    stopGrabPolling()
    if m.top.close = true then m.top.closed = true
end sub

sub updateMovieButtonFocus()
    if m.isUnavailable = true then
        ' Optional Grab Now + Watchlist + Back
        if m.playBg <> invalid then m.playBg.color = "0x2A2A32"
        if m.grabBg <> invalid then m.grabBg.color = "0x2A2A32"
        if m.watchlistBg <> invalid then m.watchlistBg.color = "0x2A2A32"
        m.backBg.color = "0x2A2A32"
        if m.randomBg <> invalid then m.randomBg.color = "0x2A2A32"
        if m.top.findNode("playShadow") <> invalid then m.top.findNode("playShadow").opacity = 0.0
        if m.top.findNode("grabShadow") <> invalid then m.top.findNode("grabShadow").opacity = 0.0
        if m.top.findNode("watchlistShadow") <> invalid then m.top.findNode("watchlistShadow").opacity = 0.0
        if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.0
        if m.top.findNode("randomShadow") <> invalid then m.top.findNode("randomShadow").opacity = 0.0

        hasGrab = (m.grabBtn <> invalid and m.grabBtn.visible = true)
        if hasGrab = true then
            if m.focusIndex = 0 then
                if m.grabBg <> invalid then m.grabBg.color = "0xE50914"
                if m.top.findNode("grabShadow") <> invalid then m.top.findNode("grabShadow").opacity = 0.5
            else if m.focusIndex = 1 then
                if m.watchlistBg <> invalid then m.watchlistBg.color = "0xE50914"
                if m.top.findNode("watchlistShadow") <> invalid then m.top.findNode("watchlistShadow").opacity = 0.5
            else
                m.focusIndex = 2
                m.backBg.color = "0xE50914"
                if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.5
            end if
        else
            if m.focusIndex = 0 then
                if m.watchlistBg <> invalid then m.watchlistBg.color = "0xE50914"
                if m.top.findNode("watchlistShadow") <> invalid then m.top.findNode("watchlistShadow").opacity = 0.5
            else
                m.focusIndex = 1
                m.backBg.color = "0xE50914"
                if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.5
            end if
        end if
        return
    end if

    m.playBg.color = "0x2A2A32"
    m.backBg.color = "0x2A2A32"
    if m.grabBg <> invalid then m.grabBg.color = "0x2A2A32"
    if m.watchlistBg <> invalid then m.watchlistBg.color = "0x2A2A32"
    if m.randomBg <> invalid then m.randomBg.color = "0x2A2A32"
    if m.top.findNode("playShadow") <> invalid then m.top.findNode("playShadow").opacity = 0.0
    if m.top.findNode("grabShadow") <> invalid then m.top.findNode("grabShadow").opacity = 0.0
    if m.top.findNode("backShadow") <> invalid then m.top.findNode("backShadow").opacity = 0.0
    if m.top.findNode("randomShadow") <> invalid then m.top.findNode("randomShadow").opacity = 0.0
    if m.top.findNode("watchlistShadow") <> invalid then m.top.findNode("watchlistShadow").opacity = 0.0

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
    if m.isUnavailable = true then
        if m.grabBtn <> invalid and m.grabBtn.visible = true then return 3
        return 2
    end if
    if m.isShow = true and m.randomBtn <> invalid and m.randomBtn.visible = true then return 3
    return 2
end function

sub toggleWatchlist()
    if m.watchlistBusy = true then return
    item = m.top.content
    if item = invalid then return

    m.watchlistBusy = true
    adding = not m.onWatchlist
    if m.softStatus <> invalid then
        if adding then
            m.softStatus.text = "Adding to Watchlist…"
        else
            m.softStatus.text = "Removing from Watchlist…"
        end if
    end if

    m.watchlistTask = createObject("roSGNode", "PlexTask")
    m.watchlistTask.config = m.top.config
    if adding then
        m.watchlistTask.action = "addToWatchlist"
    else
        m.watchlistTask.action = "removeFromWatchlist"
    end if
    m.watchlistTask.item = item
    m.watchlistTask.observeField("response", "onWatchlistMutated")
    m.watchlistTask.control = "RUN"
end sub

sub onWatchlistMutated()
    m.watchlistBusy = false
    response = m.watchlistTask.response
    if response = invalid or response.ok <> true then
        err = "Watchlist update failed"
        if response <> invalid and response.error <> invalid then err = asString(response.error)
        if m.softStatus <> invalid then m.softStatus.text = err
        return
    end if

    m.onWatchlist = (response.onWatchlist = true)
    content = m.top.content
    if content <> invalid then content.onWatchlist = m.onWatchlist
    paintWatchlistLabel()
    if m.softStatus <> invalid then
        if m.onWatchlist then
            m.softStatus.text = "Saved to your Plex Watchlist"
        else
            m.softStatus.text = "Removed from Watchlist"
        end if
    end if
end sub

' --- Grab Now (fail-open; per-episode jobs; softStatus only for focused ep) ---

sub requestGrabNow()
    if m.isUnavailable <> true then return
    if grabIsConfigured() <> true then
        if m.softStatus <> invalid then m.softStatus.text = "Grab server not configured"
        return
    end if

    item = m.top.content
    if item = invalid then return

    payload = {
        title: asString(item.title),
        year: asString(item.year),
        mediaType: asString(item.mediaType),
        tmdbId: asString(item.tmdbId),
        imdbId: asString(item.imdbId),
        tvdbId: asString(item.tvdbId),
        guid: asString(item.guid),
        grabKey: "page"
    }
    mt = LCase(payload.mediaType)
    if mt = "show" or mt = "series" or mt = "tv" or mt = "season" or mt = "episode" then
        payload.mediaType = "episode"
        payload.season = 1
        payload.episode = 1
        if item.DoesExist("season") and item.season <> invalid then payload.season = item.season
        if item.DoesExist("episode") and item.episode <> invalid then payload.episode = item.episode
    else
        payload.mediaType = "movie"
    end if

    m.focusGrabKey = "page"
    startGrabJob(payload, {
        key: "page",
        kind: "page",
        season: asString(payload.season),
        episode: asString(payload.episode),
        seasonRow: -1,
        episodeCol: -1,
        showRatingKey: ""
    })
end sub

sub requestGrabEpisode(epNode as Object, seasonRowIndex as Integer, episodeColIndex as Integer)
    if epNode = invalid then return
    if grabIsConfigured() <> true then
        if m.softStatus <> invalid then m.softStatus.text = "Grab server not configured"
        return
    end if

    key = grabKeyForEpisode(epNode)
    if key = "" then
        if m.softStatus <> invalid then m.softStatus.text = "Can't grab — missing season/episode"
        return
    end if
    if m.grabJobs <> invalid and m.grabJobs.DoesExist(key) then
        existing = m.grabJobs[key]
        if existing <> invalid and existing.active = true then
            m.focusGrabKey = key
            paintFocusSoftStatus()
            return
        end if
    end if

    show = m.top.content
    showTitle = asString(epNode.grandparentTitle)
    if showTitle = "" and show <> invalid then showTitle = asString(show.title)
    tmdbId = asString(epNode.tmdbId)
    if tmdbId = "" then tmdbId = m.showTmdbId
    if tmdbId = "" and show <> invalid then tmdbId = asString(show.tmdbId)
    showKey = asString(epNode.showRatingKey)
    if showKey = "" and show <> invalid then showKey = asString(show.ratingKey)

    seasonNum = asInteger(epNode.parentIndex)
    episodeNum = asInteger(epNode.index)
    if seasonNum = 0 then seasonNum = 1
    if episodeNum = 0 then episodeNum = 1

    payload = {
        title: showTitle,
        year: "",
        mediaType: "episode",
        tmdbId: tmdbId,
        imdbId: "",
        tvdbId: "",
        guid: "",
        season: seasonNum,
        episode: episodeNum,
        grabKey: key
    }
    if show <> invalid then payload.year = asString(show.year)

    m.focusGrabKey = key
    startGrabJob(payload, {
        key: key,
        kind: "episode",
        season: asString(epNode.parentIndex),
        episode: asString(epNode.index),
        seasonRow: seasonRowIndex,
        episodeCol: episodeColIndex,
        showRatingKey: showKey
    })
end sub

sub startGrabJob(payload as Object, meta as Object)
    if meta = invalid then return
    key = asString(meta.key)
    if key = "" then return
    if m.grabCreateBusy = true then
        if m.softStatus <> invalid and asString(m.focusGrabKey) = key then
            m.softStatus.text = "Starting another grab…"
        end if
        ' Fall through — still allow; create tasks are keyed below
    end if

    if m.grabJobs = invalid then m.grabJobs = {}
    job = {
        key: key,
        kind: asString(meta.kind),
        active: true,
        jobId: "",
        status: "starting",
        percent: 0,
        line: "Starting grab…",
        season: asString(meta.season),
        episode: asString(meta.episode),
        seasonRow: meta.seasonRow,
        episodeCol: meta.episodeCol,
        showRatingKey: asString(meta.showRatingKey),
        awaitingEpisode: false,
        awaitingPlex: false,
        pollFails: 0,
        statusBusy: false,
        findBusy: false
    }
    m.grabJobs[key] = job
    setGrabJobLine(job, "Starting grab…")
    paintGrabLabel()

    task = createObject("roSGNode", "GrabTask")
    task.config = m.top.config
    task.action = "create"
    task.item = payload
    ' Stash key on the task so the response can be matched if several overlap
    task.addFields({ grabKey: key })
    task.observeField("response", "onGrabCreated")
    if m.grabCreateTasks = invalid then m.grabCreateTasks = {}
    m.grabCreateTasks[key] = task
    m.grabCreateBusy = true
    task.control = "RUN"
    startGrabPolling()
end sub

sub onGrabCreated()
    ' Find which create task completed
    key = ""
    response = invalid
    if m.grabCreateTasks <> invalid then
        for each k in m.grabCreateTasks
            t = m.grabCreateTasks[k]
            if t <> invalid and t.response <> invalid then
                ' Prefer a task whose response just arrived and still maps to an active starting job
                job = invalid
                if m.grabJobs <> invalid and m.grabJobs.DoesExist(k) then job = m.grabJobs[k]
                if job <> invalid and job.active = true and asString(job.jobId) = "" then
                    key = k
                    response = t.response
                    m.grabCreateTasks.delete(k)
                    exit for
                end if
            end if
        end for
    end if
    if key = "" and m.grabTask <> invalid then
        ' Fallback for older single-task path
        response = m.grabTask.response
        if m.grabTask.item <> invalid then key = asString(m.grabTask.item.grabKey)
    end if
    m.grabCreateBusy = false
    if m.grabCreateTasks <> invalid then
        for each k in m.grabCreateTasks
            m.grabCreateBusy = true
            exit for
        end for
    end if

    if key = "" then key = asString(m.focusGrabKey)
    job = invalid
    if m.grabJobs <> invalid and m.grabJobs.DoesExist(key) then job = m.grabJobs[key]

    if response = invalid or response.ok <> true then
        err = "Grab unavailable — try again later"
        if response <> invalid and asString(response.error) <> "" then err = asString(response.error)
        if job <> invalid then
            setGrabJobLine(job, err)
            finishGrabJob(key)
        else if m.softStatus <> invalid and asString(m.focusGrabKey) = key then
            m.softStatus.text = err
        end if
        paintGrabLabel()
        return
    end if

    remote = response.job
    if remote = invalid or asString(remote.id) = "" then
        if job <> invalid then
            setGrabJobLine(job, "Grab unavailable — try again later")
            finishGrabJob(key)
        end if
        paintGrabLabel()
        return
    end if

    if job = invalid then
        job = { key: key, kind: "episode", active: true }
        if m.grabJobs = invalid then m.grabJobs = {}
        m.grabJobs[key] = job
    end if
    job.jobId = asString(remote.id)
    job.active = true
    paintGrabLabel()
    applyGrabJobStatusToKey(key, remote)
    startGrabPolling()
end sub

sub startGrabPolling()
    if m.grabPollTimer = invalid then return
    if grabActiveCount() = 0 then return
    m.grabPollTimer.control = "start"
end sub

sub stopGrabPolling()
    if m.grabPollTimer <> invalid then m.grabPollTimer.control = "stop"
    m.grabJobs = {}
    m.focusGrabKey = ""
    m.grabPollIndex = 0
    m.grabCreateBusy = false
    m.grabCreateTasks = {}
    paintGrabLabel()
end sub

sub finishGrabJob(key as String)
    if m.grabJobs = invalid then return
    if m.grabJobs.DoesExist(key) <> true then return
    job = m.grabJobs[key]
    if job <> invalid then job.active = false
    m.grabJobs.delete(key)
    paintGrabLabel()
    if grabActiveCount() = 0 and m.grabPollTimer <> invalid then
        m.grabPollTimer.control = "stop"
    end if
    if asString(m.focusGrabKey) = key then paintFocusSoftStatus()
end sub

sub onGrabPollFire()
    keys = grabJobKeys()
    if keys.count() = 0 then
        if m.grabPollTimer <> invalid then m.grabPollTimer.control = "stop"
        return
    end if

    if m.grabPollIndex >= keys.count() then m.grabPollIndex = 0
    key = keys[m.grabPollIndex]
    m.grabPollIndex = m.grabPollIndex + 1
    if m.grabPollIndex >= keys.count() then m.grabPollIndex = 0

    job = m.grabJobs[key]
    if job = invalid or job.active <> true then return

    if job.awaitingEpisode = true then
        if job.findBusy = true then return
        job.findBusy = true
        task = createObject("roSGNode", "PlexTask")
        task.config = m.top.config
        task.action = "findLocalEpisode"
        task.item = {
            showRatingKey: asString(job.showRatingKey),
            season: asString(job.season),
            episode: asString(job.episode),
            grabKey: key
        }
        task.addFields({ grabKey: key })
        task.observeField("response", "onFindLocalEpisode")
        if m.grabFindTasks = invalid then m.grabFindTasks = {}
        m.grabFindTasks[key] = task
        task.control = "RUN"
        return
    end if

    if job.awaitingPlex = true then
        if job.findBusy = true then return
        if m.isUnavailable <> true then
            finishGrabJob(key)
            return
        end if
        job.findBusy = true
        item = m.top.content
        if item = invalid then
            finishGrabJob(key)
            return
        end if
        loadUnavailableDetail(item)
        return
    end if

    if asString(job.jobId) = "" then return
    if job.statusBusy = true then return
    job.statusBusy = true

    task = createObject("roSGNode", "GrabTask")
    task.config = m.top.config
    task.action = "status"
    task.item = { id: job.jobId, grabKey: key }
    task.addFields({ grabKey: key })
    task.observeField("response", "onGrabStatus")
    if m.grabStatusTasks = invalid then m.grabStatusTasks = {}
    m.grabStatusTasks[key] = task
    task.control = "RUN"
end sub

sub onGrabStatus()
    key = ""
    response = invalid
    if m.grabStatusTasks <> invalid then
        for each k in m.grabStatusTasks
            t = m.grabStatusTasks[k]
            if t <> invalid and t.response <> invalid then
                job = invalid
                if m.grabJobs <> invalid and m.grabJobs.DoesExist(k) then job = m.grabJobs[k]
                if job <> invalid and job.statusBusy = true then
                    key = k
                    response = t.response
                    job.statusBusy = false
                    m.grabStatusTasks.delete(k)
                    exit for
                end if
            end if
        end for
    end if
    if key = "" then return

    job = m.grabJobs[key]
    if job = invalid then return

    if response = invalid or response.ok <> true then
        job.pollFails = job.pollFails + 1
        if job.pollFails >= 3 then
            err = "Lost contact with grab server — download may still finish in NZBGet"
            if response <> invalid and asString(response.error) <> "" then err = asString(response.error)
            setGrabJobLine(job, err)
            finishGrabJob(key)
        end if
        return
    end if

    job.pollFails = 0
    remote = response.job
    if remote = invalid then return
    applyGrabJobStatusToKey(key, remote)
end sub

sub applyGrabJobStatusToKey(key as String, remote as Object)
    if m.grabJobs = invalid or m.grabJobs.DoesExist(key) <> true then return
    job = m.grabJobs[key]
    if job = invalid or remote = invalid then return

    status = LCase(asString(remote.status))
    percent = 0
    if remote.DoesExist("percent") and remote.percent <> invalid then percent = remote.percent
    message = asString(remote.message)
    if message = "" then message = asString(remote.stage)
    job.status = status
    job.percent = percent

    if status = "ready" then
        paintGrabLabel()
        if job.kind = "episode" then
            job.awaitingEpisode = true
            job.awaitingPlex = false
            setGrabJobLine(job, "Ready — waiting for Plex to index…")
            startGrabPolling()
            return
        end if
        job.awaitingPlex = true
        job.awaitingEpisode = false
        setGrabJobLine(job, "Ready — waiting for Plex to index…")
        startGrabPolling()
        return
    end if

    if status = "failed" then
        err = message
        if err = "" then err = "Grab failed — try again or use Watchlist"
        setGrabJobLine(job, err)
        finishGrabJob(key)
        return
    end if

    line = "Grabbing"
    if status <> "" then line = UCase(Left(status, 1)) + Mid(status, 2)
    if percent > 0 then line = line + " " + StrI(percent).Trim() + "%"
    if message <> "" and message <> status then line = line + " — " + message
    setGrabJobLine(job, line)
end sub

sub onFindLocalEpisode()
    key = ""
    response = invalid
    if m.grabFindTasks <> invalid then
        for each k in m.grabFindTasks
            t = m.grabFindTasks[k]
            if t <> invalid and t.response <> invalid then
                job = invalid
                if m.grabJobs <> invalid and m.grabJobs.DoesExist(k) then job = m.grabJobs[k]
                if job <> invalid and job.findBusy = true then
                    key = k
                    response = t.response
                    job.findBusy = false
                    m.grabFindTasks.delete(k)
                    exit for
                end if
            end if
        end for
    end if
    if key = "" then return

    job = m.grabJobs[key]
    if job = invalid then return

    if response = invalid or response.ok <> true or response.item = invalid then
        setGrabJobLine(job, "Ready — waiting for Plex to index…")
        return
    end if

    promoteMissingEpisodeTile(response.item, job)
    setGrabJobLine(job, "Ready — press OK to Play")
    finishGrabJob(key)
    ' After finish, focused missing hint would clear — keep ready message briefly
    if asString(m.focusGrabKey) = key and m.softStatus <> invalid then
        m.softStatus.text = "Ready — press OK to Play"
    end if
end sub

sub promoteMissingEpisodeTile(localEp as Object, job as Object)
    if localEp = invalid or m.seasonContent = invalid then return
    seasonNo = asString(localEp.parentIndex)
    epNo = asString(localEp.index)
    preferRow = -1
    preferCol = -1
    if job <> invalid then
        preferRow = job.seasonRow
        preferCol = job.episodeCol
    end if

    rowCount = m.seasonContent.getChildCount()
    for r = 0 to rowCount - 1
        row = m.seasonContent.getChild(r)
        if row <> invalid then
            colCount = row.getChildCount()
            for c = 0 to colCount - 1
                child = row.getChild(c)
                if child <> invalid and asString(child.mediaType) = "episode" then
                    isMissing = false
                    if child.DoesExist("missing") and child.missing = true then isMissing = true
                    match = (asString(child.parentIndex) = seasonNo and asString(child.index) = epNo)
                    if preferRow >= 0 and r = preferRow and preferCol >= 0 and c = preferCol and isMissing = true then
                        match = true
                    end if
                    if match = true and isMissing = true then
                        replacement = createObject("roSGNode", "ContentNode")
                        replacement.title = formatEpisodeTitle(localEp)
                        replacement.hdPosterUrl = localEp.hdPosterUrl
                        replacement.description = localEp.description
                        replacement.addFields({
                            ratingKey: localEp.ratingKey,
                            key: localEp.key,
                            mediaType: "episode",
                            duration: localEp.duration,
                            viewOffset: localEp.viewOffset,
                            watched: localEp.watched,
                            unwatchedCount: localEp.unwatchedCount,
                            year: localEp.year,
                            hdBackdropUrl: localEp.hdBackdropUrl,
                            shortTitle: localEp.shortTitle,
                            grandparentTitle: localEp.grandparentTitle,
                            index: localEp.index,
                            parentIndex: localEp.parentIndex,
                            missing: false,
                            tmdbId: localEp.tmdbId,
                            showRatingKey: localEp.showRatingKey
                        })
                        row.replaceChild(replacement, c)
                        m.seasonRows.content = m.seasonContent
                        m.seasonRows.jumpToRowItem = [r, c]
                        applyEpisodeHeader(replacement)
                        return
                    end if
                end if
            end for
        end if
    end for
end sub

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
            hasGrab = (m.grabBtn <> invalid and m.grabBtn.visible = true)
            if hasGrab = true then
                if m.focusIndex = 0 then
                    requestGrabNow()
                else if m.focusIndex = 1 then
                    toggleWatchlist()
                else
                    m.top.closed = true
                end if
            else
                if m.focusIndex = 0 then
                    toggleWatchlist()
                else
                    m.top.closed = true
                end if
            end if
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
