sub init()
    m.top.backgroundURI = ""
    m.top.backgroundColor = "0x0A0A0A"

    m.screens = m.top.findNode("screens")
    m.loadingDim = m.top.findNode("loadingDim")
    m.statusLabel = m.top.findNode("statusLabel")

    m.config = GetPlexConfig()
    m.homeScreen = invalid
    m.detailScreen = invalid
    m.videoScreen = invalid

    m.top.observeField("focusedChild", "onFocusChanged")
    showHome()
end sub

sub onFocusChanged()
    ' no-op; screens manage their own focus
end sub

sub setLoading(isLoading as Boolean, message = "" as String)
    m.loadingDim.visible = isLoading
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
end sub

sub showHome()
    clearScreens()
    m.homeScreen = createObject("roSGNode", "HomeScreen")
    m.homeScreen.config = m.config
    m.homeScreen.observeField("selectedItem", "onHomeSelected")
    m.homeScreen.observeField("loadingMessage", "onHomeLoading")
    m.screens.appendChild(m.homeScreen)
    m.homeScreen.setFocus(true)
end sub

sub onHomeLoading()
    msg = m.homeScreen.loadingMessage
    if msg = invalid then msg = ""
    setLoading(msg <> "", msg)
end sub

sub onHomeSelected()
    item = m.homeScreen.selectedItem
    if item = invalid then return
    showDetail(item)
end sub

sub showDetail(item as Object)
    if m.detailScreen <> invalid then
        m.screens.removeChild(m.detailScreen)
        m.detailScreen = invalid
    end if

    m.detailScreen = createObject("roSGNode", "DetailScreen")
    m.detailScreen.config = m.config
    m.detailScreen.content = item
    m.detailScreen.observeField("playRequested", "onPlayRequested")
    m.detailScreen.observeField("closed", "onDetailClosed")
    m.screens.appendChild(m.detailScreen)
    m.detailScreen.setFocus(true)
end sub

sub onDetailClosed()
    if m.detailScreen <> invalid then
        m.screens.removeChild(m.detailScreen)
        m.detailScreen = invalid
    end if
    if m.homeScreen <> invalid then m.homeScreen.setFocus(true)
end sub

sub onPlayRequested()
    item = m.detailScreen.playRequested
    if item = invalid then return
    showVideo(item)
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
    end if

    return false
end function