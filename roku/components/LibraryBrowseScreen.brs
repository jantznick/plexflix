sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.rowList = m.top.findNode("rowList")
    m.rowList.observeField("rowItemSelected", "onRowItemSelected")
end sub

sub onSourceSet()
    source = m.top.source
    if source = invalid then return
    title = asString(source.title)
    if title <> "" then m.titleLabel.text = title
    loadBrowse()
end sub

sub loadBrowse()
    m.statusLabel.text = "Loading shelves..."
    m.top.loadingMessage = "Loading " + m.titleLabel.text + "..."
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "sectionBrowse"
    m.task.item = m.top.source
    m.task.observeField("response", "onBrowseLoaded")
    m.task.control = "RUN"
end sub

sub onBrowseLoaded()
    response = m.task.response
    m.top.loadingMessage = ""
    if response = invalid or response.ok <> true then
        err = "Could not load library"
        if response <> invalid and response.error <> invalid then err = response.error
        m.statusLabel.text = err
        return
    end if

    content = response.content
    if content = invalid or content.getChildCount() = 0 then
        m.statusLabel.text = "This library is empty"
        return
    end if

    m.statusLabel.text = ""
    m.rowList.content = content
    m.rowList.setFocus(true)
end sub

sub onRowItemSelected()
    info = m.rowList.rowItemSelected
    if info = invalid or info.count() < 2 then return
    row = m.rowList.content.getChild(info[0])
    if row = invalid then return
    item = row.getChild(info[1])
    if item = invalid then return
    m.top.selectedItem = nodeToItem(item)
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
        grandparentRatingKey: item.grandparentRatingKey,
        parentRatingKey: item.parentRatingKey,
        grandparentTitle: item.grandparentTitle,
        index: item.index,
        shortTitle: item.shortTitle
    }
end function

sub onCloseRequested()
    if m.top.close = true then m.top.closed = true
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        m.top.closed = true
        return true
    end if
    return false
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    return ""
end function
