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
    m.sportsScreen = invalid
    m.sportsDetailScreen = invalid
    m.section = "home"
    m.navExpanded = false
    m.activeLibraryId = ""

    m.sideNav.config = m.config
    m.sideNav.expanded = false
    m.sideNav.observeField("selected", "onNavSelected")
    m.sideNav.observeField("selectedLibrary", "onLibrarySelected")
    showHome()
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
    while m.screens.getChildCount() > 0
        m.screens.removeChildIndex(0)
    end while
    m.homeScreen = invalid
    m.detailScreen = invalid
    m.videoScreen = invalid
    m.libraryBrowseScreen = invalid
    m.sportsScreen = invalid
    m.sportsDetailScreen = invalid
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
    else if section = "sports" then
        showSports()
    end if
end sub

sub onLibrarySelected()
    lib = m.sideNav.selectedLibrary
    if lib = invalid then return
    m.section = "library"
    m.activeLibraryId = asString(lib.sectionId)
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
    m.screens.appendChild(m.homeScreen)
    m.homeScreen.setFocus(true)
end sub

sub showLibraryBrowse(source as Object)
    clearScreens()
    m.libraryBrowseScreen = createObject("roSGNode", "LibraryBrowseScreen")
    m.libraryBrowseScreen.config = m.config
    m.libraryBrowseScreen.source = source
    m.libraryBrowseScreen.observeField("selectedItem", "onBrowseSelected")
    m.libraryBrowseScreen.observeField("closed", "onLibraryBrowseClosed")
    m.libraryBrowseScreen.observeField("loadingMessage", "onSoftLoading")
    m.screens.appendChild(m.libraryBrowseScreen)
    m.libraryBrowseScreen.setFocus(true)
end sub

sub onLibraryBrowseClosed()
    ' From library browse, Back returns to Home (sidebar still has libs)
    showHome()
end sub

sub showSports()
    clearScreens()
    m.sideNav.active = "sports"
    m.sportsScreen = createObject("roSGNode", "SportsScreen")
    m.sportsScreen.config = m.config
    m.sportsScreen.observeField("selectedItem", "onSportsItemSelected")
    m.sportsScreen.observeField("loadingMessage", "onSoftLoading")
    m.screens.appendChild(m.sportsScreen)
    m.sportsScreen.setFocus(true)
end sub

sub onSoftLoading()
    msg = ""
    if m.homeScreen <> invalid then msg = m.homeScreen.loadingMessage
    if m.libraryBrowseScreen <> invalid and (msg = invalid or msg = "") then msg = m.libraryBrowseScreen.loadingMessage
    if m.sportsScreen <> invalid and (msg = invalid or msg = "") then msg = m.sportsScreen.loadingMessage
    if msg = invalid then msg = ""
    setLoading(msg <> "", msg)
end sub

sub onBrowseSelected()
    item = invalid
    if m.homeScreen <> invalid then item = m.homeScreen.selectedItem
    if item = invalid and m.libraryBrowseScreen <> invalid then item = m.libraryBrowseScreen.selectedItem
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

sub openDetailScreen(item as Object)
    if m.detailScreen <> invalid then
        m.screens.removeChild(m.detailScreen)
        m.detailScreen = invalid
    end if

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
    restoreSectionFocus()
end sub

sub onPlayRequested()
    item = m.detailScreen.playRequested
    if item = invalid then return
    showVideo(item)
end sub

sub onOpenDetails()
    item = m.detailScreen.openDetails
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
    m.videoScreen.content = item
    m.videoScreen.observeField("closed", "onVideoClosed")
    m.screens.appendChild(m.videoScreen)
    m.videoScreen.setFocus(true)
end sub

sub onVideoClosed()
    if m.videoScreen <> invalid then
        m.screens.removeChild(m.videoScreen)
        m.videoScreen = invalid
    end if
    if m.detailScreen <> invalid then
        m.detailScreen.setFocus(true)
    else if m.sportsDetailScreen <> invalid then
        m.sportsDetailScreen.setFocus(true)
    else
        restoreSectionFocus()
    end if
end sub

sub restoreSectionFocus()
    if m.section = "library" and m.libraryBrowseScreen <> invalid then
        m.libraryBrowseScreen.setFocus(true)
    else if m.section = "sports" and m.sportsScreen <> invalid then
        m.sportsScreen.setFocus(true)
    else if m.homeScreen <> invalid then
        m.homeScreen.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        if m.videoScreen <> invalid then
            m.videoScreen.close = true
            return true
        else if m.sportsDetailScreen <> invalid then
            m.sportsDetailScreen.close = true
            return true
        else if m.detailScreen <> invalid then
            m.detailScreen.close = true
            return true
        else if m.libraryBrowseScreen <> invalid then
            m.libraryBrowseScreen.close = true
            return true
        else if m.navExpanded then
            setNavExpanded(false)
            return true
        end if
    else if key = "left" and not m.navExpanded and m.detailScreen = invalid and m.videoScreen = invalid and m.sportsDetailScreen = invalid then
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
