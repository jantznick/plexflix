sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.ratingLabel = m.top.findNode("ratingLabel")
    m.summaryLabel = m.top.findNode("summaryLabel")
    m.reviewLabel = m.top.findNode("reviewLabel")

    m.movieActions = m.top.findNode("movieActions")
    m.playBtn = m.top.findNode("playBtn")
    m.startOverBtn = m.top.findNode("startOverBtn")
    m.trailerBtn = m.top.findNode("trailerBtn")
    m.watchedBtn = m.top.findNode("watchedBtn")
    m.backBtn = m.top.findNode("backBtn")
    m.randomBtn = m.top.findNode("randomBtn")
    m.grabBtn = m.top.findNode("grabBtn")
    m.grabBg = m.top.findNode("grabBg")
    m.grabLabel = m.top.findNode("grabLabel")
    m.watchlistBtn = m.top.findNode("watchlistBtn")
    m.watchlistBg = m.top.findNode("watchlistBg")
    m.watchlistLabel = m.top.findNode("watchlistLabel")
    m.playBg = m.top.findNode("playBg")
    m.startOverBg = m.top.findNode("startOverBg")
    m.trailerBg = m.top.findNode("trailerBg")
    m.watchedBg = m.top.findNode("watchedBg")
    m.backBg = m.top.findNode("backBg")
    m.randomBg = m.top.findNode("randomBg")
    m.playLabel = m.top.findNode("playLabel")
    m.startOverLabel = m.top.findNode("startOverLabel")
    m.trailerLabel = m.top.findNode("trailerLabel")
    m.watchedLabel = m.top.findNode("watchedLabel")
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
    m.actionIds = []
    m.isShow = false
    m.isUnavailable = false
    m.onWatchlist = false
    m.watchlistBusy = false
    m.grabJobs = {}
    m.focusGrabKey = ""
    m.grabPollIndex = 0
    m.grabCreateBusy = false
    m.showTmdbId = ""
    m.focusEpisodeMissing = false
    m.unavailableIsShow = false
    m.grabStatusHold = ""
    m.grabStatusHoldKey = ""
    m.watchedBusy = false
    m.itemWatched = false
    m.canResume = false
    m.trailer = invalid
    m.reviews = []
    m.seasons = []
    m.seasonQueue = 0
    m.seasonContent = invalid
    m.pendingSeason = invalid
    m.relatedContent = invalid
    m.focusEpisodeKey = ""
    m.focusSeasonKey = ""
    m.showHeader = invalid
    m.headerMode = "show"

    rebuildActionRow()
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
    m.focusEpisodeMissing = false
    m.unavailableIsShow = false
    m.grabStatusHold = ""
    m.grabStatusHoldKey = ""
    m.watchedBusy = false
    m.trailer = invalid
    m.reviews = []
    m.canResume = false
    m.itemWatched = (item.DoesExist("watched") and item.watched = true)
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

    refreshPlayState(item)
end sub

sub refreshPlayState(item as Object)
    if m.isUnavailable = true then
        m.canResume = false
        return
    end if
    if item = invalid then return

    resume = false
    mediaType = asString(item.mediaType)
    if mediaType = "show" or mediaType = "season" then
        leaves = asInteger(item.leafCount)
        viewed = asInteger(item.viewedLeafCount)
        resume = (viewed > 0 and viewed < leaves)
        if asInteger(item.viewOffset) > 0 then resume = true
    else
        resume = (asInteger(item.viewOffset) > 0)
    end if

    m.canResume = resume
    if m.playLabel <> invalid then
        if resume then m.playLabel.text = "Resume" else m.playLabel.text = "Play"
    end if
    if item.DoesExist("watched") then m.itemWatched = (item.watched = true)
    paintWatchedLabel()
    rebuildActionRow()
end sub

sub paintWatchedLabel()
    if m.watchedLabel = invalid then return
    if m.itemWatched = true then
        m.watchedLabel.text = "Mark Unwatched"
    else
        m.watchedLabel.text = "Mark Watched"
    end if
end sub

sub applyShowHeader(item as Object)
    if item = invalid then return
    m.titleLabel.text = asString(item.title)
    summary = asString(item.description)
    tagline = ""
    if item.DoesExist("tagline") then tagline = asString(item.tagline)
    if summary = "" and tagline <> "" then summary = tagline
    m.summaryLabel.text = summary
    if m.softStatus <> invalid then m.softStatus.text = ""

    metaBits = []
    year = asString(item.year)
    if year <> "" then metaBits.push(year)
    contentRating = asString(item.contentRating)
    if contentRating <> "" then metaBits.push(contentRating)
    durationBit = durationMeta(item)
    if durationBit <> "" then metaBits.push(durationBit)
    mediaType = asString(item.mediaType)
    if mediaType <> "" then metaBits.push(titleCaseType(mediaType))
    genreBit = genreSummary(item)
    if genreBit <> "" then metaBits.push(genreBit)
    watchBit = watchedSummary(item)
    if watchBit <> "" then metaBits.push(watchBit)
    m.metaLabel.text = joinStrings(metaBits, "  ·  ")
    paintRatingLine(item)
    if m.reviews = invalid or m.reviews.count() = 0 then
        if m.reviewLabel <> invalid then m.reviewLabel.text = ""
    end if
    m.headerMode = "show"
end sub

sub paintRatingLine(item as Object)
    if m.ratingLabel = invalid then return
    if item = invalid then
        m.ratingLabel.text = ""
        return
    end if

    bits = []
    audience = ""
    critic = ""
    if item.DoesExist("audienceRating") then audience = asString(item.audienceRating)
    if item.DoesExist("criticRating") then critic = asString(item.criticRating)
    if audience = "" then audience = asString(item.rating)
    if audience <> "" and critic <> "" and audience <> critic then
        bits.push("Audience " + audience)
        bits.push("Critic " + critic)
    else if audience <> "" then
        bits.push(audience + " ★")
    else if critic <> "" then
        bits.push(critic + " ★")
    end if
    m.ratingLabel.text = joinStrings(bits, "  ·  ")
end sub

sub paintReviews(reviews as Object)
    m.reviews = reviews
    if m.reviewLabel = invalid then return
    if reviews = invalid or reviews.count() = 0 then
        m.reviewLabel.text = ""
        return
    end if

    rev = reviews[0]
    text = asString(rev.text)
    if text = "" then
        m.reviewLabel.text = ""
        return
    end if
    ' Keep the detail chrome short — one clipped pull-quote
    if Len(text) > 160 then text = Left(text, 157) + "…"
    source = asString(rev.source)
    author = asString(rev.author)
    prefix = ""
    if source <> "" then
        prefix = source
    else if author <> "" then
        prefix = author
    end if
    if prefix <> "" then
        m.reviewLabel.text = Chr(34) + text + Chr(34) + " — " + prefix
    else
        m.reviewLabel.text = Chr(34) + text + Chr(34)
    end if
end sub

function genreSummary(item as Object) as String
    if item = invalid or not item.DoesExist("genres") then return ""
    genres = item.genres
    if genres = invalid or GetInterface(genres, "ifArray") = invalid then return ""
    if genres.count() = 0 then return ""
    limit = genres.count()
    if limit > 2 then limit = 2
    parts = []
    for i = 0 to limit - 1
        parts.push(asString(genres[i]))
    end for
    return joinStrings(parts, ", ")
end function

function durationMeta(item as Object) as String
    ms = asInteger(item.duration)
    if ms <= 0 then return ""
    minutes = Int(ms / 60000)
    if minutes < 1 then return ""
    if minutes < 60 then return asString(minutes) + " min"
    hours = Int(minutes / 60)
    leftover = minutes - hours * 60
    if leftover = 0 then return asString(hours) + " hr"
    return asString(hours) + " hr " + asString(leftover) + " min"
end function

sub rememberShowHeader()
    m.showHeader = {
        title: m.titleLabel.text,
        meta: m.metaLabel.text,
        rating: "",
        summary: m.summaryLabel.text,
        review: "",
        backdrop: ""
    }
    if m.ratingLabel <> invalid then m.showHeader.rating = m.ratingLabel.text
    if m.reviewLabel <> invalid then m.showHeader.review = m.reviewLabel.text
    if m.backdrop <> invalid and m.backdrop.uri <> invalid then
        m.showHeader.backdrop = m.backdrop.uri
    end if
end sub

sub restoreShowHeader()
    if m.showHeader = invalid then return
    m.titleLabel.text = asString(m.showHeader.title)
    m.metaLabel.text = asString(m.showHeader.meta)
    if m.ratingLabel <> invalid then m.ratingLabel.text = asString(m.showHeader.rating)
    m.summaryLabel.text = asString(m.showHeader.summary)
    if m.reviewLabel <> invalid then m.reviewLabel.text = asString(m.showHeader.review)
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
    durationBit = durationMeta(ep)
    if durationBit <> "" then metaBits.push(durationBit)
    metaBits.push("Episode")
    watchBit = watchedSummary(ep)
    if watchBit <> "" then metaBits.push(watchBit)
    m.metaLabel.text = joinStrings(metaBits, "  ·  ")
    paintRatingLine(ep)

    summary = asString(ep.description)
    if summary = "" and m.showHeader <> invalid then summary = asString(m.showHeader.summary)
    m.summaryLabel.text = summary

    if asString(ep.hdBackdropUrl) <> "" and m.backdrop <> invalid then
        m.backdrop.uri = ep.hdBackdropUrl
    end if
    m.headerMode = "episode"

    ' Episode focus drives Resume / From Start / Mark Watched for the leaf
    m.itemWatched = (ep.DoesExist("watched") and ep.watched = true)
    m.canResume = (asInteger(ep.viewOffset) > 0)
    if m.playLabel <> invalid then
        if m.canResume then m.playLabel.text = "Resume" else m.playLabel.text = "Play"
    end if
    paintWatchedLabel()
    rebuildActionRow()
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
        newKey = grabKeyForEpisode(item)
        if asString(m.grabStatusHoldKey) <> "" and asString(m.grabStatusHoldKey) <> newKey then
            m.grabStatusHold = ""
            m.grabStatusHoldKey = ""
        end if
        m.focusGrabKey = newKey
        m.focusEpisodeMissing = (item.DoesExist("missing") and item.missing = true)
        paintFocusSoftStatus()
        ' Play / From Start / Mark Watched only apply to episodes we actually own
        if m.isUnavailable <> true then rebuildActionRow()
    else
        ' Cast / other rows under the same list — show synopsis again
        m.focusGrabKey = ""
        m.focusEpisodeMissing = false
        m.grabStatusHold = ""
        m.grabStatusHoldKey = ""
        restoreShowHeader()
        if m.top.content <> invalid then refreshPlayState(m.top.content)
        paintFocusSoftStatus()
        if m.isUnavailable <> true then rebuildActionRow()
    end if
end sub

sub showTvMode()
    m.isUnavailable = false
    ' Keep polling if any episode grabs are still active on this page
    if grabActiveCount() = 0 then stopGrabPolling()
    m.movieActions.visible = true
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = false
    if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 420]
    m.relatedPanel.visible = false
    m.tvPanel.visible = true
    if m.tvPanel <> invalid then m.tvPanel.translation = [0, 420]
    m.poster.width = 210
    m.poster.height = 315
    m.poster.translation = [0, 0]
    m.titleLabel.translation = [248, 12]
    m.metaLabel.translation = [248, 92]
    if m.ratingLabel <> invalid then m.ratingLabel.translation = [248, 126]
    m.summaryLabel.translation = [248, 158]
    m.summaryLabel.height = 72
    if m.reviewLabel <> invalid then m.reviewLabel.translation = [248, 236]
    m.movieActions.translation = [248, 292]
    if m.softStatus <> invalid then m.softStatus.translation = [248, 360]
    m.focusIndex = 0
    rebuildActionRow()
end sub

sub showMovieMode()
    m.isUnavailable = false
    stopGrabPolling()
    m.movieActions.visible = true
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = false
    if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 420]
    m.tvPanel.visible = false
    m.relatedPanel.visible = false
    m.poster.width = 210
    m.poster.height = 315
    m.poster.translation = [0, 0]
    m.titleLabel.translation = [248, 12]
    m.metaLabel.translation = [248, 92]
    if m.ratingLabel <> invalid then m.ratingLabel.translation = [248, 126]
    m.summaryLabel.translation = [248, 158]
    m.summaryLabel.height = 72
    if m.reviewLabel <> invalid then m.reviewLabel.translation = [248, 236]
    m.movieActions.translation = [248, 292]
    if m.softStatus <> invalid then m.softStatus.translation = [248, 360]
    m.relatedContent = createObject("roSGNode", "ContentNode")
    m.relatedRows.content = m.relatedContent
    m.focusIndex = 0
    rebuildActionRow()
    m.top.setFocus(true)
end sub

sub showUnavailableMode(item as Object)
    m.isUnavailable = true
    m.trailer = invalid
    m.canResume = false
    m.focusEpisodeMissing = false
    mt = ""
    if item <> invalid then mt = LCase(asString(item.mediaType))
    m.unavailableIsShow = (mt = "show" or mt = "series" or mt = "tv" or mt = "season")
    m.isShow = m.unavailableIsShow
    m.tvPanel.visible = false
    m.relatedPanel.visible = false
    m.movieActions.visible = true
    if m.ratingLabel <> invalid then m.ratingLabel.text = ""
    if m.reviewLabel <> invalid then m.reviewLabel.text = ""
    if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 440]
    if m.unavailablePanel <> invalid then m.unavailablePanel.visible = true
    m.movieActions.translation = [248, 348]
    if m.softStatus <> invalid then m.softStatus.translation = [248, 412]

    if m.unavailableBody <> invalid then m.unavailableBody.text = unavailableMessage(item)
    setSoftStatusHint("Looking up details & similar titles…")
    paintWatchlistLabel()
    paintGrabLabel()

    m.relatedContent = createObject("roSGNode", "ContentNode")
    m.relatedRows.content = m.relatedContent
    m.focusIndex = 0
    rebuildActionRow()
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

function pageGrabJob() as Object
    if m.grabJobs = invalid then return invalid
    if m.grabJobs.DoesExist("page") <> true then return invalid
    job = m.grabJobs["page"]
    if job = invalid or job.active <> true then return invalid
    return job
end function

sub paintFocusSoftStatus()
    if m.softStatus = invalid then return

    ' Page-level unavailable grab always owns the status line on that screen
    if m.isUnavailable = true then
        pageJob = pageGrabJob()
        if pageJob <> invalid then
            m.softStatus.text = asString(pageJob.line)
            return
        end if
    end if

    key = asString(m.focusGrabKey)
    if key <> "" and key <> "page" and m.grabJobs <> invalid and m.grabJobs.DoesExist(key) then
        job = m.grabJobs[key]
        if job <> invalid and job.active = true then
            m.softStatus.text = asString(job.line)
            return
        end if
    end if

    ' Keep a just-finished error/ready line until focus moves away
    if asString(m.grabStatusHold) <> "" and key <> "" and key = asString(m.grabStatusHoldKey) then
        m.softStatus.text = asString(m.grabStatusHold)
        return
    end if

    ' No active grab for the focused ep — missing hint or clear
    if key <> "" and key <> "page" then
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
    key = asString(job.key)
    showLine = false
    if key = "page" and m.isUnavailable = true then
        showLine = true
    else if key <> "" and key = asString(m.focusGrabKey) then
        showLine = true
    end if
    if showLine = true and m.softStatus <> invalid then m.softStatus.text = line
end sub

' Detail/lookup copy must never bury an in-flight Grab Now status line
sub setSoftStatusHint(text as String)
    if m.isUnavailable = true and pageGrabJob() <> invalid then
        paintFocusSoftStatus()
        return
    end if
    if m.softStatus <> invalid then m.softStatus.text = text
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
    pageJob = pageGrabJob()
    ' Never replace an active grab line with the lookup spinner
    if pageJob = invalid then
        setSoftStatusHint("Looking up details & similar titles…")
    else if pageJob.awaitingPlex = true then
        ' Keep the Ready/waiting copy; poll path owns the text
    else
        paintFocusSoftStatus()
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
    pageJob = pageGrabJob()
    if pageJob <> invalid then pageJob.findBusy = false

    ' Post-grab page flip: keep rechecking until Plex has the title
    if pageJob <> invalid and pageJob.awaitingPlex = true then
        if response <> invalid and response.ok = true and response.localItem <> invalid then
            localItem = response.localItem
            if response.onWatchlist = true then localItem.onWatchlist = true
            finishGrabJob("page")
            setSoftStatusHint("Ready — opening…")
            m.top.content = localItem
            return
        end if
        setGrabJobLine(pageJob, "Ready — waiting for Plex to index…")
        return
    end if

    ' If a grab started while this lookup was in flight, keep its status
    if pageGrabJob() <> invalid then
        paintFocusSoftStatus()
        if response = invalid or response.ok <> true then return
        ' Fall through to refresh similar/cast under the grab line
    else
        setSoftStatusHint("")
        if response = invalid or response.ok <> true then
            setSoftStatusHint("Couldn't load extra details — try similar picks below if any")
            return
        end if
    end if

    ' Same plex:// guid already in the local library — promote to a normal Play page
    ' (skip while a grab is running — don't tear down the job UI mid-download)
    if response.localItem <> invalid and pageGrabJob() = invalid then
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
            if asString(response.tmdbId) <> "" then
                content.tmdbId = asString(response.tmdbId)
                m.showTmdbId = asString(response.tmdbId)
            else if asString(detail.tmdbId) <> "" then
                content.tmdbId = asString(detail.tmdbId)
                m.showTmdbId = asString(detail.tmdbId)
            end if
            content.onWatchlist = m.onWatchlist
            content.isDiscover = true
            content.unavailable = true
        end if
    else if response.DoesExist("tmdbId") and asString(response.tmdbId) <> "" then
        m.showTmdbId = asString(response.tmdbId)
        content = m.top.content
        if content <> invalid then content.tmdbId = m.showTmdbId
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

    ' Unavailable series: load TMDB season rails (newest first). Movies keep similar/cast.
    if m.unavailableIsShow = true then
        if m.relatedPanel <> invalid then m.relatedPanel.translation = [0, 760]
        if similarItems.count() > 0 or castItems.count() > 0 then
            m.relatedPanel.visible = true
        end if
        if pageGrabJob() = invalid then
            if m.showTmdbId <> "" then
                setSoftStatusHint("Loading seasons…")
            else
                setSoftStatusHint("Couldn't resolve seasons — grab individual episodes once listed")
            end if
        end if
        loadUnavailableShowSeasons()
    else if similarItems.count() > 0 or castItems.count() > 0 then
        m.relatedPanel.visible = true
        if similarItems.count() > 0 then
            setSoftStatusHint("Similar titles already in your library")
        else
            setSoftStatusHint("")
        end if
    else
        setSoftStatusHint("No close matches in your library yet")
    end if

    m.focusIndex = 0
    rebuildActionRow()
    m.top.setFocus(true)
end sub

sub loadUnavailableShowSeasons()
    if m.unavailableIsShow <> true then return
    item = m.top.content
    if item = invalid then return
    if m.showTmdbId = "" and asString(item.tmdbId) = "" then return

    m.loadMode = "seasons"
    m.pendingSeason = item
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "showSeasons"
    m.task.item = {
        ratingKey: "",
        title: asString(item.title),
        year: asString(item.year),
        hdPosterUrl: asString(item.hdPosterUrl),
        hdShowPosterUrl: asString(item.hdShowPosterUrl),
        tmdbId: m.showTmdbId,
        showTmdbId: m.showTmdbId,
        mediaType: "show"
    }
    if asString(m.task.item.tmdbId) = "" then m.task.item.tmdbId = asString(item.tmdbId)
    if asString(m.task.item.showTmdbId) = "" then m.task.item.showTmdbId = asString(item.tmdbId)
    m.task.observeField("response", "onChildrenLoaded")
    m.task.control = "RUN"
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
        ' Prefer season-stashed show identity (set when merging TMDB season rows)
        if item.DoesExist("showRatingKey") then payload.showRatingKey = asString(item.showRatingKey)
        if item.DoesExist("showTitle") then payload.showTitle = asString(item.showTitle)
        if item.DoesExist("showYear") then payload.showYear = asString(item.showYear)
        if item.DoesExist("showPosterUrl") then payload.showPosterUrl = asString(item.showPosterUrl)
        if item.DoesExist("showTmdbId") and asString(item.showTmdbId) <> "" then
            payload.showTmdbId = asString(item.showTmdbId)
        else if item.DoesExist("tmdbId") and asString(item.tmdbId) <> "" then
            payload.showTmdbId = asString(item.tmdbId)
        end if
        if show <> invalid then
            if payload.showRatingKey = "" then payload.showRatingKey = asString(show.ratingKey)
            if payload.showTitle = "" then payload.showTitle = asString(show.title)
            if payload.showYear = "" then payload.showYear = asString(show.year)
            if payload.grandparentTitle = "" then payload.grandparentTitle = asString(show.title)
            if payload.showPosterUrl = "" then
                payload.showPosterUrl = asString(show.hdPosterUrl)
                if payload.showPosterUrl = "" then payload.showPosterUrl = asString(show.hdShowPosterUrl)
            end if
            if payload.showTmdbId = "" and m.showTmdbId <> "" then payload.showTmdbId = m.showTmdbId
            if payload.showTmdbId = "" and show.DoesExist("tmdbId") then
                payload.showTmdbId = asString(show.tmdbId)
            end if
        end if
        m.task.action = "seasonEpisodes"
        m.task.item = payload
    else if mode = "seasons" then
        show = item
        payload = item
        if show <> invalid then
            payload = {
                ratingKey: asString(show.ratingKey),
                title: asString(show.title),
                year: asString(show.year),
                hdPosterUrl: asString(show.hdPosterUrl),
                hdShowPosterUrl: asString(show.hdShowPosterUrl),
                tmdbId: m.showTmdbId,
                showTmdbId: m.showTmdbId,
                mediaType: "show"
            }
            if payload.tmdbId = "" and show.DoesExist("tmdbId") then
                payload.tmdbId = asString(show.tmdbId)
                payload.showTmdbId = payload.tmdbId
            end if
        end if
        m.task.action = "showSeasons"
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
        if response.DoesExist("showTmdbId") and asString(response.showTmdbId) <> "" then
            m.showTmdbId = asString(response.showTmdbId)
            content = m.top.content
            if content <> invalid then content.tmdbId = m.showTmdbId
        end if
        m.seasons = items
        m.seasonQueue = 0
        m.seasonContent = createObject("roSGNode", "ContentNode")
        ' Create empty labeled season rows immediately so rails appear early
        for each season in items
            row = m.seasonContent.createChild("ContentNode")
            title = asString(season.title)
            if title = "" then
                if asString(season.index) <> "" then
                    title = "Season " + asString(season.index)
                else
                    title = "Season"
                end if
            end if
            row.title = title
        end for
        m.seasonRows.content = m.seasonContent
        if items.count() = 0 then
            if m.isUnavailable = true and m.unavailableIsShow = true then
                setSoftStatusHint("No seasons found — try Watchlist instead")
            end if
            return
        end if
        if m.isUnavailable = true and m.unavailableIsShow = true then
            ' Discover series: season rails under the unavailable banner
            if m.tvPanel <> invalid then
                m.tvPanel.translation = [0, 450]
                m.tvPanel.visible = true
            end if
            if pageGrabJob() = invalid then setSoftStatusHint("OK on a grey episode to Grab Now")
        else
            ' Prefer the Continue Watching season first so focus lands sooner
            prioritizeFocusSeason()
            if m.focusEpisodeKey <> "" then m.seasonRows.setFocus(true)
        end if
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
        season = m.seasons[i]
        if season = invalid then
            ' skip
        else if asString(season.ratingKey) <> "" and asString(season.ratingKey) = m.focusSeasonKey then
            target = i
            exit for
        else if asString(season.index) <> "" and asString(season.index) = m.focusSeasonKey then
            ' Fallback: focusSeasonKey sometimes carries the season number
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
        if title = "" then
            if asString(season.index) <> "" then
                title = "Season " + asString(season.index)
            else
                title = "Season"
            end if
        end if
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
        seasonKey = asString(season.ratingKey)
        seasonNum = asString(season.index)
        if seasonKey <> m.focusSeasonKey and seasonNum <> m.focusSeasonKey then return
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
        refreshPlayState(detail)
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

    if response.trailer <> invalid then m.trailer = response.trailer
    ' Reviews belong on the show/movie chrome; stash them even if an episode is focused
    paintReviews(response.reviews)
    if detail <> invalid then
        if m.headerMode = "episode" then
            ' Temporarily restore show copy so the cached header keeps the review
            restoreShowHeader()
            paintReviews(response.reviews)
            rememberShowHeader()
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
        else
            rememberShowHeader()
        end if
    end if
    rebuildActionRow()

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
    out = {
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
    if item.DoesExist("tagline") then out.tagline = item.tagline
    if item.DoesExist("criticRating") then out.criticRating = item.criticRating
    if item.DoesExist("audienceRating") then out.audienceRating = item.audienceRating
    if item.DoesExist("genres") then out.genres = item.genres
    return out
end function

sub onCloseRequested()
    stopGrabPolling()
    if m.top.close = true then m.top.closed = true
end sub

sub rebuildActionRow()
    ' Pack visible buttons left-to-right; focus order matches left→right
    specs = []
    if m.isUnavailable = true then
        ' Whole-show Grab Now is not supported — only individual episodes.
        ' Movies still get Grab Now; Discover series use season/episode rails.
        if m.unavailableIsShow <> true and grabIsConfigured() = true then
            specs.push({ id: "grab", node: m.grabBtn, width: 200 })
        end if
        specs.push({ id: "watchlist", node: m.watchlistBtn, width: 300 })
        specs.push({ id: "back", node: m.backBtn, width: 140 })
    else if m.focusEpisodeMissing = true then
        ' Focused episode isn't in the library — no Play / watched controls
        if m.trailer <> invalid then
            specs.push({ id: "trailer", node: m.trailerBtn, width: 170 })
        end if
        specs.push({ id: "back", node: m.backBtn, width: 140 })
        if m.isShow = true then
            specs.push({ id: "random", node: m.randomBtn, width: 170 })
        end if
    else
        specs.push({ id: "play", node: m.playBtn, width: 200 })
        if m.canResume = true then
            specs.push({ id: "startOver", node: m.startOverBtn, width: 200 })
        end if
        if m.trailer <> invalid then
            specs.push({ id: "trailer", node: m.trailerBtn, width: 170 })
        end if
        specs.push({ id: "watched", node: m.watchedBtn, width: 220 })
        specs.push({ id: "back", node: m.backBtn, width: 140 })
        if m.isShow = true then
            specs.push({ id: "random", node: m.randomBtn, width: 170 })
        end if
    end if

    ' Hide every optional control first, then reveal the ones in specs
    hideActionNode(m.playBtn)
    hideActionNode(m.startOverBtn)
    hideActionNode(m.trailerBtn)
    hideActionNode(m.watchedBtn)
    hideActionNode(m.grabBtn)
    hideActionNode(m.watchlistBtn)
    hideActionNode(m.backBtn)
    hideActionNode(m.randomBtn)

    m.actionIds = []
    x = 0
    gap = 16
    for each spec in specs
        if spec.node <> invalid then
            spec.node.visible = true
            spec.node.translation = [x, 0]
            m.actionIds.push(spec.id)
            x = x + spec.width + gap
        end if
    end for

    if m.focusIndex < 0 then m.focusIndex = 0
    if m.actionIds.count() = 0 then
        m.focusIndex = 0
    else if m.focusIndex >= m.actionIds.count() then
        m.focusIndex = m.actionIds.count() - 1
    end if
    updateMovieButtonFocus()
end sub

sub hideActionNode(node as Object)
    if node = invalid then return
    node.visible = false
end sub

sub updateMovieButtonFocus()
    clearActionFocus()
    if m.actionIds = invalid or m.actionIds.count() = 0 then return
    if m.focusIndex < 0 or m.focusIndex >= m.actionIds.count() then m.focusIndex = 0
    id = m.actionIds[m.focusIndex]
    setActionFocused(id, true)
end sub

sub clearActionFocus()
    setActionFocused("play", false)
    setActionFocused("startOver", false)
    setActionFocused("trailer", false)
    setActionFocused("watched", false)
    setActionFocused("grab", false)
    setActionFocused("watchlist", false)
    setActionFocused("back", false)
    setActionFocused("random", false)
end sub

sub setActionFocused(id as String, focused as Boolean)
    bg = invalid
    shadow = invalid
    if id = "play" then
        bg = m.playBg
        shadow = m.top.findNode("playShadow")
    else if id = "startOver" then
        bg = m.startOverBg
        shadow = m.top.findNode("startOverShadow")
    else if id = "trailer" then
        bg = m.trailerBg
        shadow = m.top.findNode("trailerShadow")
    else if id = "watched" then
        bg = m.watchedBg
        shadow = m.top.findNode("watchedShadow")
    else if id = "grab" then
        bg = m.grabBg
        shadow = m.top.findNode("grabShadow")
    else if id = "watchlist" then
        bg = m.watchlistBg
        shadow = m.top.findNode("watchlistShadow")
    else if id = "back" then
        bg = m.backBg
        shadow = m.top.findNode("backShadow")
    else if id = "random" then
        bg = m.randomBg
        shadow = m.top.findNode("randomShadow")
    end if

    if bg <> invalid then
        if focused then bg.color = "0xE50914" else bg.color = "0x2A2A32"
    end if
    if shadow <> invalid then
        if focused then shadow.opacity = 0.5 else shadow.opacity = 0.0
    end if
end sub

function actionButtonCount() as Integer
    if m.actionIds = invalid then return 0
    return m.actionIds.count()
end function

function focusedActionId() as String
    if m.actionIds = invalid or m.actionIds.count() = 0 then return ""
    if m.focusIndex < 0 or m.focusIndex >= m.actionIds.count() then return ""
    return m.actionIds[m.focusIndex]
end function

sub activateFocusedAction()
    id = focusedActionId()
    if id = "play" then
        requestMoviePlay(false)
    else if id = "startOver" then
        requestMoviePlay(true)
    else if id = "trailer" then
        requestTrailerPlay()
    else if id = "watched" then
        toggleWatched()
    else if id = "grab" then
        requestGrabNow()
    else if id = "watchlist" then
        toggleWatchlist()
    else if id = "back" then
        m.top.closed = true
    else if id = "random" then
        requestRandomEpisode()
    end if
end sub

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

    mt = LCase(asString(item.mediaType))
    ' No whole-series grab — only movies at page level; TV is per-episode OK
    if mt = "show" or mt = "series" or mt = "tv" or mt = "season" then
        if m.softStatus <> invalid then
            m.softStatus.text = "Pick an episode below to Grab Now"
        end if
        if m.tvPanel <> invalid and m.tvPanel.visible = true then
            m.seasonRows.setFocus(true)
        end if
        return
    end if

    payload = {
        title: asString(item.title),
        year: asString(item.year),
        mediaType: "movie",
        tmdbId: asString(item.tmdbId),
        imdbId: asString(item.imdbId),
        tvdbId: asString(item.tvdbId),
        guid: asString(item.guid),
        grabKey: "page"
    }

    m.focusGrabKey = "page"
    m.grabStatusHold = ""
    m.grabStatusHoldKey = ""
    startGrabJob(payload, {
        key: "page",
        kind: "page",
        season: "",
        episode: "",
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
    m.grabStatusHold = ""
    m.grabStatusHoldKey = ""
    startGrabJob(payload, {
        key: key,
        kind: "episode",
        season: asString(seasonNum),
        episode: asString(episodeNum),
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
            finishGrabJob(key, true)
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
            finishGrabJob(key, true)
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

sub finishGrabJob(key as String, keepLine = false as Boolean)
    if m.grabJobs = invalid then return
    if m.grabJobs.DoesExist(key) <> true then return
    job = m.grabJobs[key]
    lastLine = ""
    if job <> invalid then
        job.active = false
        lastLine = asString(job.line)
    end if
    m.grabJobs.delete(key)
    paintGrabLabel()
    if grabActiveCount() = 0 and m.grabPollTimer <> invalid then
        m.grabPollTimer.control = "stop"
    end if
    if keepLine = true and lastLine <> "" and asString(m.focusGrabKey) = key then
        m.grabStatusHold = lastLine
        m.grabStatusHoldKey = key
        if m.softStatus <> invalid then m.softStatus.text = lastLine
        return
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
            finishGrabJob(key, true)
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
    ' ParseJson often boxes numbers as Float — never pass that to StrI
    percent = 0
    if remote.DoesExist("percent") then percent = asInteger(remote.percent)
    message = asString(remote.message)
    if message = "" then message = asString(remote.stage)
    job.status = status
    job.percent = percent

    if status = "ready" then
        paintGrabLabel()
        if job.kind = "episode" then
            ' Discover-only shows have no Plex show key yet — don't spin forever
            if asString(job.showRatingKey) = "" then
                setGrabJobLine(job, "Downloaded — refresh Plex when it appears")
                finishGrabJob(key, true)
                return
            end if
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
        finishGrabJob(key, true)
        return
    end if

    line = "Grabbing"
    if status <> "" then line = UCase(Left(status, 1)) + Mid(status, 2)
    if percent > 0 then line = line + " " + asString(percent) + "%"
    if message <> "" and LCase(message) <> status then line = line + " — " + message
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
    m.focusEpisodeMissing = false
    if m.isUnavailable <> true then rebuildActionRow()
    setGrabJobLine(job, "Ready — press OK to Play")
    finishGrabJob(key, true)
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
    rebuildActionRow()
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

sub requestMoviePlay(startOver = false as Boolean)
    if m.isUnavailable = true then return
    if m.focusEpisodeMissing = true then return
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
                        if ep.DoesExist("missing") and ep.missing = true then
                            requestGrabEpisode(ep, info[0], info[1])
                            return
                        end if
                        payload = nodeToItem(ep)
                        if startOver = true then payload.viewOffset = 0
                        m.top.playRequested = payload
                        return
                    end if
                end if
            end if
        end if
    end if

    payload = nodeToItem(item)
    if startOver = true then payload.viewOffset = 0
    m.top.playRequested = payload
end sub

sub requestTrailerPlay()
    if m.trailer = invalid then return
    m.top.playRequested = nodeToItem(m.trailer)
end sub

sub toggleWatched()
    if m.isUnavailable = true then return
    if m.watchedBusy = true then return

    target = watchedTargetItem()
    if target = invalid then return
    ratingKey = asString(target.ratingKey)
    if ratingKey = "" then return

    m.watchedBusy = true
    markingWatched = not m.itemWatched
    if m.softStatus <> invalid then
        if markingWatched then
            m.softStatus.text = "Marking watched…"
        else
            m.softStatus.text = "Marking unwatched…"
        end if
    end if

    m.watchedTask = createObject("roSGNode", "PlexTask")
    m.watchedTask.config = m.top.config
    m.watchedTask.action = "scrobble"
    m.watchedTask.item = {
        ratingKey: ratingKey,
        unwatch: not markingWatched
    }
    m.watchedTask.observeField("response", "onWatchedMutated")
    m.watchedTask.control = "RUN"
end sub

function watchedTargetItem() as Object
    ' Prefer the focused episode on a show page; otherwise the title itself
    if m.isShow = true and m.seasonRows <> invalid and m.seasonRows.content <> invalid then
        info = m.seasonRows.rowItemFocused
        if info <> invalid and info.count() >= 2 then
            row = m.seasonRows.content.getChild(info[0])
            if row <> invalid then
                ep = row.getChild(info[1])
                if ep <> invalid and asString(ep.mediaType) = "episode" then
                    return nodeToItem(ep)
                end if
            end if
        end if
    end if
    return m.top.content
end function

sub onWatchedMutated()
    m.watchedBusy = false
    response = m.watchedTask.response
    if response = invalid or response.ok <> true then
        err = "Couldn't update watched state"
        if response <> invalid and response.error <> invalid then err = asString(response.error)
        if m.softStatus <> invalid then m.softStatus.text = err
        return
    end if

    m.itemWatched = not m.itemWatched
    ' Clearing progress when marking watched; restoring resume when unwatching isn't available
    if m.itemWatched = true then m.canResume = false
    content = m.top.content
    if content <> invalid then
        content.watched = m.itemWatched
        if m.itemWatched = true then content.viewOffset = 0
    end if

    ' Keep the focused episode tile in sync when we marked a leaf
    if m.isShow = true and m.seasonRows <> invalid and m.seasonRows.content <> invalid then
        info = m.seasonRows.rowItemFocused
        if info <> invalid and info.count() >= 2 then
            row = m.seasonRows.content.getChild(info[0])
            if row <> invalid then
                ep = row.getChild(info[1])
                if ep <> invalid and asString(ep.mediaType) = "episode" then
                    ep.watched = m.itemWatched
                    if m.itemWatched = true then ep.viewOffset = 0
                end if
            end if
        end if
    end if

    paintWatchedLabel()
    if m.playLabel <> invalid then
        if m.canResume then m.playLabel.text = "Resume" else m.playLabel.text = "Play"
    end if
    rebuildActionRow()
    if m.softStatus <> invalid then
        if m.itemWatched then
            m.softStatus.text = "Marked watched"
        else
            m.softStatus.text = "Marked unwatched"
        end if
    end if
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
        activateFocusedAction()
        return true
    else if key = "play"
        if m.isUnavailable = true then return true
        requestMoviePlay(false)
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
