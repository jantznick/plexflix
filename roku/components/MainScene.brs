sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x07070B"

    m.sideNav = m.top.findNode("sideNav")
    m.navScrim = m.top.findNode("navScrim")
    m.contentHost = m.top.findNode("contentHost")
    m.screens = m.top.findNode("screens")
    m.loadingBanner = m.top.findNode("loadingBanner")
    m.statusLabel = m.top.findNode("statusLabel")

    m.config = GetPlexConfig()
    m.homeScreen = invalid
    m.detailScreen = invalid
    m.videoScreen = invalid
    m.libraryBrowseScreen = invalid
    m.libraryAllScreen = invalid
    m.libraryHubSource = invalid
    m.sportsScreen = invalid
    m.sportsDetailScreen = invalid
    m.castDetailScreen = invalid
    m.liveTvScreen = invalid
    m.section = "home"
    m.navExpanded = false
    m.activeLibraryId = ""

    m.sideNav.config = m.config
    m.sideNav.expanded = false
    m.sideNav.observeField("selected", "onNavSelected")
    m.sideNav.observeField("selectedLibrary", "onLibrarySelected")
    ' The nav can collapse itself (Back); keep the scrim and focus in sync when it does
    m.sideNav.observeField("expanded", "onNavExpandedChanged")
    showHome()
end sub

sub onNavExpandedChanged(event as Object)
    expanded = (event.getData() = true)
    if expanded = m.navExpanded then return
    setNavExpanded(expanded)
end sub

sub setNavExpanded(expanded as Boolean)
    m.navExpanded = expanded
    m.sideNav.expanded = expanded
    m.navScrim.visible = expanded
    if not expanded then
        restoreSectionFocus()
    end if
end sub

sub setLoading(isLoading as Boolean, message = "" as String)
    m.loadingBanner.visible = isLoading
    if isLoading then
        m.statusLabel.text = message
    else
        m.statusLabel.text = ""
    end if
end sub

sub clearScreens()
    ' Stop the library hub's focus guard before its node leaves the tree
    if m.libraryBrowseScreen <> invalid then m.libraryBrowseScreen.suspended = true
    while m.screens.getChildCount() > 0
        m.screens.removeChildIndex(0)
    end while
    m.homeScreen = invalid
    m.detailScreen = invalid
    m.videoScreen = invalid
    m.libraryBrowseScreen = invalid
    m.libraryAllScreen = invalid
    m.libraryHubSource = invalid
    m.sportsScreen = invalid
    m.sportsDetailScreen = invalid
    m.castDetailScreen = invalid
    m.liveTvScreen = invalid
end sub

sub onNavSelected()
    section = m.sideNav.selected
    if section = invalid or section = "" then return
    if section = "library" then return ' handled by onLibrarySelected

    m.section = section
    m.activeLibraryId = ""
    setNavExpanded(false)
    if section = "home" then
        showHome()
    else if section = "livetv" then
        showLiveTv()
    else if section = "sports" then
        showSports()
    end if
end sub

sub onLibrarySelected(event as Object)
    lib = event.getData()
    if lib = invalid then return
    sectionId = asString(lib.sectionId)

    ' Re-picking the library you are already in shouldn't refetch the whole hub
    if sectionId <> "" and sectionId = m.activeLibraryId and m.libraryBrowseScreen <> invalid then
        setNavExpanded(false)
        if m.libraryAllScreen <> invalid then onLibraryAllClosed()
        return
    end if

    m.section = "library"
    m.activeLibraryId = sectionId
    setNavExpanded(false)
    showLibraryBrowse(lib)
end sub

sub showHome()
    clearScreens()
    m.sideNav.active = "home"
    m.homeScreen = createObject("roSGNode", "HomeScreen")
    m.homeScreen.config = m.config
    m.homeScreen.observeField("selectedItem", "onBrowseSelected")
    m.homeScreen.observeField("loadingMessage", "onSoftLoading")
    m.homeScreen.observeField("openMenu", "onOpenMenu")
    m.screens.appendChild(m.homeScreen)
    m.homeScreen.setFocus(true)
end sub

function dialogIsOpen() as Boolean
    ' wasClosed guards against a stale dialog reference blocking the remote
    if m.top.dialog = invalid then return false
    return m.top.dialog.wasClosed <> true
end function

sub onOpenMenu()
    if m.videoScreen <> invalid or m.detailScreen <> invalid then return
    if dialogIsOpen() then return
    setNavExpanded(true)
    m.sideNav.setFocus(true)
end sub

sub showLibraryBrowse(source as Object)
    clearScreens()
    m.libraryHubSource = source
    m.libraryBrowseScreen = createObject("roSGNode", "LibraryBrowseScreen")
    m.libraryBrowseScreen.config = m.config
    m.libraryBrowseScreen.source = source
    m.libraryBrowseScreen.observeField("selectedItem", "onBrowseSelected")
    m.libraryBrowseScreen.observeField("viewAllRequested", "onLibraryViewAll")
    m.libraryBrowseScreen.observeField("closed", "onLibraryBrowseClosed")
    m.libraryBrowseScreen.observeField("loadingMessage", "onSoftLoading")
    m.libraryBrowseScreen.observeField("openMenu", "onOpenMenu")
    m.screens.appendChild(m.libraryBrowseScreen)
    m.libraryBrowseScreen.setFocus(true)
end sub

sub onLibraryViewAll(event as Object)
    payload = event.getData()
    if payload = invalid then return
    showLibraryAll(payload)
end sub

sub showLibraryAll(source as Object)
    if m.libraryAllScreen <> invalid then
        m.screens.removeChild(m.libraryAllScreen)
        m.libraryAllScreen = invalid
    end if
    ' Park the library hub: its mosaic/shelves keep rendering (and stealing focus) otherwise
    if m.libraryBrowseScreen <> invalid then
        m.libraryBrowseScreen.suspended = true
        m.libraryBrowseScreen.visible = false
    end if
    m.libraryAllScreen = createObject("roSGNode", "LibraryAllScreen")
    m.libraryAllScreen.config = m.config
    m.libraryAllScreen.source = source
    m.libraryAllScreen.observeField("selectedItem", "onBrowseSelected")
    m.libraryAllScreen.observeField("closed", "onLibraryAllClosed")
    m.libraryAllScreen.observeField("loadingMessage", "onSoftLoading")
    m.libraryAllScreen.observeField("openMenu", "onOpenMenu")
    m.screens.appendChild(m.libraryAllScreen)
    m.libraryAllScreen.setFocus(true)
end sub

sub onLibraryAllClosed()
    if m.libraryAllScreen <> invalid then
        m.screens.removeChild(m.libraryAllScreen)
        m.libraryAllScreen = invalid
    end if
    if m.libraryBrowseScreen <> invalid then
        m.libraryBrowseScreen.visible = true
        m.libraryBrowseScreen.suspended = false
        m.libraryBrowseScreen.setFocus(true)
        m.libraryBrowseScreen.refocus = true
    else if m.libraryHubSource <> invalid then
        showLibraryBrowse(m.libraryHubSource)
    end if
end sub

sub onLibraryBrowseClosed()
    ' From library browse, Back returns to Home (sidebar still has libs)
    showHome()
end sub

sub showLiveTv()
    clearScreens()
    m.sideNav.active = "livetv"
    m.liveTvScreen = createObject("roSGNode", "LiveTvScreen")
    m.liveTvScreen.config = m.config
    m.liveTvScreen.observeField("selectedItem", "onLiveTvSelected")
    m.liveTvScreen.observeField("loadingMessage", "onSoftLoading")
    m.liveTvScreen.observeField("openMenu", "onOpenMenu")
    m.screens.appendChild(m.liveTvScreen)
    m.liveTvScreen.setFocus(true)
end sub

sub onLiveTvSelected()
    item = m.liveTvScreen.selectedItem
    if item = invalid then return
    mediaType = asString(item.mediaType)
    if mediaType = "recording" or (asString(item.ratingKey) <> "" and mediaType <> "livetv") then
        ' Completed recordings behave like normal library media
        if mediaType = "recording" then item.mediaType = "episode"
        showVideo(item)
        return
    end if
    showVideo(item)
end sub

sub showSports()
    clearScreens()
    m.sideNav.active = "sports"
    m.sportsScreen = createObject("roSGNode", "SportsScreen")
    m.sportsScreen.config = m.config
    m.sportsScreen.observeField("selectedItem", "onSportsItemSelected")
    m.sportsScreen.observeField("loadingMessage", "onSoftLoading")
    m.sportsScreen.observeField("openMenu", "onOpenMenu")
    m.screens.appendChild(m.sportsScreen)
    m.sportsScreen.setFocus(true)
end sub

sub onSoftLoading()
    msg = ""
    ' The top-most screen wins so a parked screen can't keep the banner alive
    if m.libraryAllScreen <> invalid then
        msg = m.libraryAllScreen.loadingMessage
    else if m.libraryBrowseScreen <> invalid then
        msg = m.libraryBrowseScreen.loadingMessage
    else if m.liveTvScreen <> invalid then
        msg = m.liveTvScreen.loadingMessage
    else if m.sportsScreen <> invalid then
        msg = m.sportsScreen.loadingMessage
    else if m.homeScreen <> invalid then
        msg = m.homeScreen.loadingMessage
    end if
    if msg = invalid then msg = ""
    setLoading(msg <> "", msg)
end sub

sub onBrowseSelected(event as Object)
    ' Read the payload off the event: home, library hub and library grid all share this handler
    item = event.getData()
    if item = invalid then return
    showDetail(item)
end sub

sub onSportsItemSelected()
    item = m.sportsScreen.selectedItem
    if item = invalid then return
    showSportsDetail(item)
end sub

sub showSportsDetail(item as Object)
    if m.sportsDetailScreen <> invalid then
        m.screens.removeChild(m.sportsDetailScreen)
        m.sportsDetailScreen = invalid
    end if

    m.sportsDetailScreen = createObject("roSGNode", "SportsDetailScreen")
    m.sportsDetailScreen.content = item
    m.sportsDetailScreen.observeField("playRequested", "onSportsPlayRequested")
    m.sportsDetailScreen.observeField("closed", "onSportsDetailClosed")
    m.screens.appendChild(m.sportsDetailScreen)
    m.sportsDetailScreen.setFocus(true)
    m.sportsDetailScreen.refocus = true
end sub

sub onSportsDetailClosed()
    if m.sportsDetailScreen <> invalid then
        m.screens.removeChild(m.sportsDetailScreen)
        m.sportsDetailScreen = invalid
    end if
    if m.sportsScreen <> invalid then m.sportsScreen.setFocus(true)
end sub

sub onSportsPlayRequested()
    item = m.sportsDetailScreen.playRequested
    if item = invalid then return
    showVideo(item)
end sub

sub showDetail(item as Object)
    if item = invalid then return

    if asString(item.mediaType) = "actor" then
        showCastDetail(item)
        return
    end if

    if asString(item.mediaType) = "episode" then
        if asString(item.grandparentRatingKey) <> "" then
            openShowForEpisode(item)
            return
        end if
        resolveEpisodeThenShow(item)
        return
    end if

    openDetailScreen(item)
end sub

sub showCastDetail(item as Object)
    if m.castDetailScreen <> invalid then
        m.screens.removeChild(m.castDetailScreen)
        m.castDetailScreen = invalid
    end if
    m.castDetailScreen = createObject("roSGNode", "CastDetailScreen")
    m.castDetailScreen.config = m.config
    m.castDetailScreen.content = item
    m.castDetailScreen.observeField("openDetails", "onCastOpenDetails")
    m.castDetailScreen.observeField("closed", "onCastDetailClosed")
    m.screens.appendChild(m.castDetailScreen)
    m.castDetailScreen.setFocus(true)
end sub

sub onCastOpenDetails()
    item = m.castDetailScreen.openDetails
    if item = invalid then return
    showDetail(item)
end sub

sub onCastDetailClosed()
    if m.castDetailScreen <> invalid then
        m.screens.removeChild(m.castDetailScreen)
        m.castDetailScreen = invalid
    end if
    if m.detailScreen <> invalid then
        m.detailScreen.setFocus(true)
    else
        restoreSectionFocus()
    end if
end sub

sub openShowForEpisode(episode as Object)
    focusEpisodeKey = asString(episode.ratingKey)
    focusSeasonKey = asString(episode.parentRatingKey)
    showItem = {
        title: asString(episode.grandparentTitle),
        mediaType: "show",
        ratingKey: asString(episode.grandparentRatingKey),
        key: "/library/metadata/" + asString(episode.grandparentRatingKey),
        hdPosterUrl: episode.hdPosterUrl,
        hdBackdropUrl: episode.hdBackdropUrl,
        description: episode.description,
        focusEpisodeKey: focusEpisodeKey,
        focusSeasonKey: focusSeasonKey
    }
    openDetailScreen(showItem)
end sub

sub resolveEpisodeThenShow(episode as Object)
    setLoading(true, "Opening series...")
    m.resolveTask = createObject("roSGNode", "PlexTask")
    m.resolveTask.config = m.config
    m.resolveTask.action = "resolveEpisodeShow"
    m.resolveTask.item = episode
    m.resolveTask.observeField("response", "onEpisodeShowResolved")
    m.resolveTask.control = "RUN"
end sub

sub onEpisodeShowResolved()
    setLoading(false, "")
    response = m.resolveTask.response
    if response = invalid or response.ok <> true or response.show = invalid then
        openDetailScreen(m.resolveTask.item)
        return
    end if

    show = response.show
    openDetailScreen({
        title: show.title,
        description: show.description,
        year: show.year,
        rating: show.rating,
        contentRating: show.contentRating,
        mediaType: "show",
        ratingKey: show.ratingKey,
        key: show.key,
        hdPosterUrl: show.hdPosterUrl,
        hdBackdropUrl: show.hdBackdropUrl,
        focusEpisodeKey: response.focusEpisodeKey,
        focusSeasonKey: response.focusSeasonKey
    })
end sub

sub parkLibrarySurfaces(parked as Boolean)
    ' Poster grids / mosaics keep costing GPU time behind a full screen overlay
    if m.libraryAllScreen <> invalid then
        m.libraryAllScreen.visible = not parked
        return
    end if
    if m.libraryBrowseScreen <> invalid then
        m.libraryBrowseScreen.suspended = parked
        m.libraryBrowseScreen.visible = not parked
    end if
end sub

sub openDetailScreen(item as Object)
    if m.detailScreen <> invalid then
        m.screens.removeChild(m.detailScreen)
        m.detailScreen = invalid
    end if
    parkLibrarySurfaces(true)

    m.detailScreen = createObject("roSGNode", "DetailScreen")
    m.detailScreen.config = m.config
    m.detailScreen.content = item
    m.detailScreen.observeField("playRequested", "onPlayRequested")
    m.detailScreen.observeField("openDetails", "onOpenDetails")
    m.detailScreen.observeField("closed", "onDetailClosed")
    m.screens.appendChild(m.detailScreen)
    m.detailScreen.setFocus(true)
end sub

sub onDetailClosed()
    if m.detailScreen <> invalid then
        m.screens.removeChild(m.detailScreen)
        m.detailScreen = invalid
    end if
    parkLibrarySurfaces(false)
    ' Explicitly restore focus so the remote never goes dead after Back
    restoreSectionFocus()
end sub

sub onPlayRequested()
    item = m.detailScreen.playRequested
    if item = invalid then return
    showVideo(item)
end sub

sub onOpenDetails()
    item = invalid
    if m.detailScreen <> invalid then item = m.detailScreen.openDetails
    if item = invalid then return
    showDetail(item)
end sub

sub showVideo(item as Object)
    if m.videoScreen <> invalid then
        m.screens.removeChild(m.videoScreen)
        m.videoScreen = invalid
    end if

    m.videoScreen = createObject("roSGNode", "VideoScreen")
    m.videoScreen.config = m.config
    m.videoScreen.observeField("closed", "onVideoClosed")
    m.videoScreen.observeField("playbackReport", "onPlaybackReport")

    ' In the tree before the content lands: setting content is what starts
    ' playback, and for a direct URL that happens synchronously, so the Video
    ' node would otherwise be told to play while it is still detached
    m.screens.appendChild(m.videoScreen)
    m.videoScreen.content = item
    m.videoScreen.setFocus(true)
end sub

sub onPlaybackReport(event as Object)
    payload = event.getData()
    if payload = invalid or payload.actions = invalid then return

    ' Run from here, not from the player: the final timeline, the scrobble and
    ' the transcode teardown all fire as VideoScreen is being removed, and a
    ' Task whose owning node has gone can be collected before it finishes.
    if m.playbackTasks = invalid then
        m.playbackTasks = [invalid, invalid, invalid, invalid, invalid, invalid]
        m.playbackSlot = 0
    end if

    for each entry in payload.actions
        action = asString(entry.action)
        if action <> "" then
            task = createObject("roSGNode", "PlexTask")
            task.config = m.config
            task.action = action
            task.item = entry.item
            task.control = "RUN"

            ' A small ring keeps each call referenced long enough to finish
            ' without the list growing for the life of the channel
            m.playbackTasks[m.playbackSlot] = task
            m.playbackSlot = (m.playbackSlot + 1) MOD m.playbackTasks.count()
        end if
    end for
end sub

sub onVideoClosed()
    failure = ""
    if m.videoScreen <> invalid then
        failure = asString(m.videoScreen.failure)
        m.screens.removeChild(m.videoScreen)
        m.videoScreen = invalid
    end if
    if m.detailScreen <> invalid then
        m.detailScreen.setFocus(true)
    else if m.sportsDetailScreen <> invalid then
        m.sportsDetailScreen.setFocus(true)
        m.sportsDetailScreen.refocus = true
        if failure <> "" then m.sportsDetailScreen.streamError = failure
    else
        restoreSectionFocus()
    end if
end sub

sub restoreSectionFocus()
    ' setFocus first, then refocus: a screen's refocus handler may hand focus to
    ' one of its own buttons, and setFocus on the screen would take it straight back
    if m.section = "library" and m.libraryAllScreen <> invalid then
        m.libraryAllScreen.setFocus(true)
        m.libraryAllScreen.refocus = true
    else if m.section = "library" and m.libraryBrowseScreen <> invalid then
        m.libraryBrowseScreen.setFocus(true)
        m.libraryBrowseScreen.refocus = true
    else if m.section = "livetv" and m.liveTvScreen <> invalid then
        m.liveTvScreen.setFocus(true)
        m.liveTvScreen.refocus = true
    else if m.section = "sports" and m.sportsScreen <> invalid then
        m.sportsScreen.setFocus(true)
        m.sportsScreen.refocus = true
    else if m.homeScreen <> invalid then
        m.homeScreen.setFocus(true)
        m.homeScreen.refocus = true
    else
        showHome()
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' A dialog (search keyboard) owns the remote while it is up
    if dialogIsOpen() then return false

    if key = "back"
        if m.videoScreen <> invalid then
            m.videoScreen.close = true
            return true
        else if m.sportsDetailScreen <> invalid then
            m.sportsDetailScreen.close = true
            return true
        else if m.castDetailScreen <> invalid then
            m.castDetailScreen.close = true
            return true
        else if m.detailScreen <> invalid then
            m.detailScreen.close = true
            return true
        else if m.libraryAllScreen <> invalid then
            m.libraryAllScreen.close = true
            return true
        else if m.libraryBrowseScreen <> invalid then
            m.libraryBrowseScreen.close = true
            return true
        else if m.navExpanded then
            setNavExpanded(false)
            return true
        end if
    else if key = "left" and not m.navExpanded and m.videoScreen = invalid and m.detailScreen = invalid and m.castDetailScreen = invalid then
        ' Allow Left → menu from home / libraries / sports / sports detail
        setNavExpanded(true)
        m.sideNav.setFocus(true)
        return true
    else if key = "right" and m.navExpanded then
        setNavExpanded(false)
        return true
    end if

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
