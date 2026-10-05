sub init()
    m.statusLabel = m.top.findNode("statusLabel")
    m.playlistList = m.top.findNode("playlistList")
    m.itemsRow = m.top.findNode("itemsRow")
    m.playlistList.observeField("itemFocused", "onPlaylistFocused")
    m.playlistList.observeField("itemSelected", "onPlaylistSelected")
    m.itemsRow.observeField("rowItemSelected", "onItemSelected")
    m.playlists = []
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    loadPlaylists()
end sub

sub loadPlaylists()
    m.statusLabel.text = "Loading playlists..."
    m.top.loadingMessage = "Loading playlists..."
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "playlists"
    m.task.observeField("response", "onPlaylistsLoaded")
    m.task.control = "RUN"
end sub

sub onPlaylistsLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if response = invalid or response.ok <> true then
        err = "Could not load playlists"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    m.playlists = response.items
    root = createObject("roSGNode", "ContentNode")
    for each pl in m.playlists
        child = root.createChild("ContentNode")
        child.title = pl.title
    end for
    m.playlistList.content = root
    if m.playlists.count() = 0 then
        m.statusLabel.text = "No playlists found"
    else
        m.statusLabel.text = ""
        m.playlistList.jumpToItem = 0
        m.playlistList.setFocus(true)
        loadPlaylistItems(m.playlists[0])
    end if
end sub

sub onPlaylistFocused()
    idx = m.playlistList.itemFocused
    if idx = invalid or idx < 0 or idx >= m.playlists.count() then return
    loadPlaylistItems(m.playlists[idx])
end sub

sub onPlaylistSelected()
    m.itemsRow.setFocus(true)
end sub

sub loadPlaylistItems(playlist as Object)
    m.itemsTask = createObject("roSGNode", "PlexTask")
    m.itemsTask.config = m.top.config
    m.itemsTask.action = "playlistItems"
    m.itemsTask.item = playlist
    m.itemsTask.observeField("response", "onPlaylistItemsLoaded")
    m.itemsTask.control = "RUN"
end sub

sub onPlaylistItemsLoaded()
    response = m.itemsTask.response
    root = createObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    row.title = "Items"
    if response <> invalid and response.ok = true and response.items <> invalid then
        for each item in response.items
            child = row.createChild("ContentNode")
            child.title = item.title
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
                grandparentRatingKey: item.grandparentRatingKey,
                parentRatingKey: item.parentRatingKey,
                grandparentTitle: item.grandparentTitle,
                index: item.index,
                shortTitle: item.shortTitle
            })
        end for
    end if
    m.itemsRow.content = root
end sub

sub onItemSelected()
    info = m.itemsRow.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.itemsRow.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return
    m.top.selectedItem = {
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
        grandparentRatingKey: item.grandparentRatingKey,
        parentRatingKey: item.parentRatingKey,
        grandparentTitle: item.grandparentTitle,
        index: item.index,
        shortTitle: item.shortTitle
    }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "right" and m.playlistList.hasFocus() then
        m.itemsRow.setFocus(true)
        return true
    else if key = "left" and m.itemsRow.hasFocus() then
        m.playlistList.setFocus(true)
        return true
    end if
    return false
end function
