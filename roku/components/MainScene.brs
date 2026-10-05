sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x08080A"

    m.sideNav = m.top.findNode("sideNav")
    m.contentHost = m.top.findNode("contentHost")
    m.screens = m.top.findNode("screens")
    m.loadingBanner = m.top.findNode("loadingBanner")
    m.loadingLogo = m.top.findNode("loadingLogo")
    m.statusLabel = m.top.findNode("statusLabel")

    m.config = GetPlexConfig()
    m.homeScreen = invalid
    m.detailScreen = invalid
    m.videoScreen = invalid
    m.playlistsScreen = invalid
    m.sportsScreen = invalid
    m.section = "home"
    m.navFocused = false

    m.sideNav.observeField("selected", "onNavSelected")
    showHome()
end sub

sub setLoading(isLoading as Boolean, message = "" as String)
    ' Non-blocking banner — never covers the interactive UI
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
    m.playlistsScreen = invalid
    m.sportsScreen = invalid
end sub

sub onNavSelected()
    section = m.sideNav.selected
    if section = invalid or section = "" then return
    m.section = section
    if section = "home" then
        showHome()
    else if section = "playlists" then
        showPlaylists()
    else if section = "sports" then
        showSports()
    end if
end sub

sub showHome()
    clearScreens()
    m.sideNav.active = "home"
    m.homeScreen = createObject("roSGNode", "HomeScreen")
    m.homeScreen.config = m.config
    m.homeScreen.observeField("selectedItem", "onHomeSelected")
    m.homeScreen.observeField("loadingMessage", "onSoftLoading")
    m.screens.appendChild(m.homeScreen)
    m.homeScreen.setFocus(true)
    m.navFocused = false
end sub

sub showPlaylists()
    clearScreens()
    m.sideNav.active = "playlists"
    m.playlistsScreen = createObject("roSGNode", "PlaylistsScreen")
    m.playlistsScreen.config = m.config
    m.playlistsScreen.observeField("selectedItem", "onHomeSelected")
    m.playlistsScreen.observeField("loadingMessage", "onSoftLoading")
    m.screens.appendChild(m.playlistsScreen)
    m.playlistsScreen.setFocus(true)
    m.navFocused = false
end sub

sub showSports()
    clearScreens()
    m.sideNav.active = "sports"
    m.sportsScreen = createObject("roSGNode", "SportsScreen")
    m.sportsScreen.config = m.config
    m.sportsScreen.observeField("selectedItem", "onSportsSelected")
    m.sportsScreen.observeField("loadingMessage", "onSoftLoading")
    m.screens.appendChild(m.sportsScreen)
    m.sportsScreen.setFocus(true)
    m.navFocused = false
end sub

sub onSoftLoading()
    msg = ""
    if m.homeScreen <> invalid then msg = m.homeScreen.loadingMessage
    if m.playlistsScreen <> invalid and (msg = invalid or msg = "") then msg = m.playlistsScreen.loadingMessage
    if m.sportsScreen <> invalid and (msg = invalid or msg = "") then msg = m.sportsScreen.loadingMessage
    if msg = invalid then msg = ""
    setLoading(msg <> "", msg)
end sub

sub onHomeSelected()
    item = invalid
    if m.homeScreen <> invalid then item = m.homeScreen.selectedItem
    if item = invalid and m.playlistsScreen <> invalid then item = m.playlistsScreen.selectedItem
    if item = invalid then return
    showDetail(item)
end sub

sub onSportsSelected()
    item = m.sportsScreen.selectedItem
    if item = invalid then return
    showVideo(item)
end sub

sub showDetail(item as Object)
    if item = invalid then return

    ' Continue Watching episodes open the parent show with that episode focused
    if asString(item.mediaType) = "episode" and asString(item.grandparentRatingKey) <> "" then
        focusEpisodeKey = asString(item.ratingKey)
        focusSeasonKey = asString(item.parentRatingKey)
        item = {
            title: asString(item.grandparentTitle),
            mediaType: "show",
            ratingKey: asString(item.grandparentRatingKey),
            key: "/library/metadata/" + asString(item.grandparentRatingKey),
            hdPosterUrl: item.hdPosterUrl,
            hdBackdropUrl: item.hdBackdropUrl,
            description: item.description,
            focusEpisodeKey: focusEpisodeKey,
            focusSeasonKey: focusSeasonKey
        }
    end if

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
    m.navFocused = false
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
    m.navFocused = false
end sub

sub onVideoClosed()
    if m.videoScreen <> invalid then
        m.screens.removeChild(m.videoScreen)
        m.videoScreen = invalid
    end if
    if m.detailScreen <> invalid then
        m.detailScreen.setFocus(true)
    else
        restoreSectionFocus()
    end if
end sub

sub restoreSectionFocus()
    if m.section = "playlists" and m.playlistsScreen <> invalid then
        m.playlistsScreen.setFocus(true)
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
        else if m.detailScreen <> invalid then
            m.detailScreen.close = true
            return true
        end if
    else if key = "left" and not m.navFocused and m.detailScreen = invalid and m.videoScreen = invalid then
        m.navFocused = true
        m.sideNav.setFocus(true)
        return true
    else if key = "right" and m.navFocused then
        m.navFocused = false
        restoreSectionFocus()
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
