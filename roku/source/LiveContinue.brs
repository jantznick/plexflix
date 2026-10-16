' Recently watched Live TV / Cable channel → Continue Watching.
' Persist the last tune locally; Home pins it when the airing is still on
' or ended within the last hour (leftAt covers sports that run past the guide).

function SaveLiveContinueWatch(item as Object, profileId as String) as Boolean
    if item = invalid then return false
    mediaType = liveContinueStr(item.mediaType)
    source = liveContinueStr(item.source)
    if mediaType <> "livetv" and not (mediaType = "sport" and source = "cable") then return false

    channelKey = liveContinueStr(item.key)
    if channelKey = "" then return false

    now = CreateObject("roDateTime").AsSeconds()
    beginsAt = liveContinueInt(item.beginsAt)
    endsAt = liveContinueInt(item.endsAt)
    entry = {
        profileId: profileId,
        leftAt: now,
        beginsAt: beginsAt,
        endsAt: endsAt,
        title: liveContinueStr(item.title),
        shortTitle: liveContinueStr(item.shortTitle),
        description: liveContinueStr(item.description),
        channelName: liveContinueStr(item.channelName),
        mediaType: mediaType,
        source: source,
        key: channelKey,
        channelId: liveContinueStr(item.channelId),
        tuneAlt: liveContinueStr(item.tuneAlt),
        dvrId: liveContinueStr(item.dvrId),
        epgId: liveContinueStr(item.epgId),
        feedId: liveContinueStr(item.feedId),
        streamUrl: liveContinueStr(item.streamUrl),
        streamFormat: liveContinueStr(item.streamFormat),
        hdPosterUrl: liveContinueStr(item.hdPosterUrl),
        hdBackdropUrl: liveContinueStr(item.hdBackdropUrl),
        guid: liveContinueStr(item.guid),
        showGuid: liveContinueStr(item.showGuid),
        year: liveContinueStr(item.year),
        contentRating: liveContinueStr(item.contentRating),
        rating: liveContinueStr(item.rating),
        programKind: liveContinueStr(item.programKind)
    }
    if entry.shortTitle = "" then entry.shortTitle = entry.channelName
    if entry.title = "" then entry.title = entry.shortTitle
    if entry.streamFormat = "" and mediaType = "livetv" then entry.streamFormat = "hls"

    return writeLiveContinueJson(liveContinueRegistryKey(profileId), FormatJson(entry))
end function

function LoadLiveContinueWatch(profileId as String) as Dynamic
    raw = readLiveContinueJson(liveContinueRegistryKey(profileId))
    if raw = "" then return invalid
    entry = ParseJson(raw)
    if entry = invalid or GetInterface(entry, "ifAssociativeArray") = invalid then return invalid
    if liveContinueStr(entry.key) = "" then return invalid
    return entry
end function

function LiveContinueStillRelevant(entry as Object, nowSec = 0 as Integer) as Boolean
    if entry = invalid then return false
    if nowSec <= 0 then nowSec = CreateObject("roDateTime").AsSeconds()
    endsAt = liveContinueInt(entry.endsAt)
    leftAt = liveContinueInt(entry.leftAt)
    anchor = endsAt
    if leftAt > anchor then anchor = leftAt
    if anchor <= 0 then return false
    ' Still the same airing, or within an hour of it ending / of leaving mid-overrun
    return nowSec <= anchor + 3600
end function

function LiveContinueToHomeItem(entry as Object) as Dynamic
    if entry = invalid then return invalid
    if not LiveContinueStillRelevant(entry) then return invalid

    channelName = liveContinueStr(entry.channelName)
    shortTitle = liveContinueStr(entry.shortTitle)
    if shortTitle = "" then shortTitle = channelName
    if shortTitle = "" then shortTitle = "Live TV"

    title = liveContinueStr(entry.title)
    if title = "" then
        title = shortTitle
        if channelName <> "" and shortTitle <> channelName then title = shortTitle + "  ·  " + channelName
    end if

    mediaType = liveContinueStr(entry.mediaType)
    if mediaType = "" then mediaType = "livetv"
    source = liveContinueStr(entry.source)
    streamFormat = liveContinueStr(entry.streamFormat)
    if streamFormat = "" then streamFormat = "hls"

    art = liveContinueStr(entry.hdPosterUrl)
    backdrop = liveContinueStr(entry.hdBackdropUrl)
    if backdrop = "" then backdrop = art
    ' Portrait CW tiles need a poster; fall back to backdrop so the tile isn't empty
    if art = "" then art = backdrop

    return {
        title: title,
        shortTitle: shortTitle,
        description: liveContinueStr(entry.description),
        mediaType: mediaType,
        source: source,
        ratingKey: "",
        key: liveContinueStr(entry.key),
        channelId: liveContinueStr(entry.channelId),
        tuneAlt: liveContinueStr(entry.tuneAlt),
        dvrId: liveContinueStr(entry.dvrId),
        epgId: liveContinueStr(entry.epgId),
        feedId: liveContinueStr(entry.feedId),
        channelName: channelName,
        beginsAt: liveContinueInt(entry.beginsAt),
        endsAt: liveContinueInt(entry.endsAt),
        guid: liveContinueStr(entry.guid),
        showGuid: liveContinueStr(entry.showGuid),
        streamUrl: liveContinueStr(entry.streamUrl),
        streamFormat: streamFormat,
        hdPosterUrl: art,
        hdBackdropUrl: backdrop,
        hdShowPosterUrl: art,
        year: liveContinueStr(entry.year),
        contentRating: liveContinueStr(entry.contentRating),
        rating: liveContinueStr(entry.rating),
        programKind: liveContinueStr(entry.programKind),
        duration: 0,
        viewOffset: 0,
        watched: false,
        unwatchedCount: 0,
        viewedLeafCount: 0,
        leafCount: 0,
        childCount: 0,
        grandparentRatingKey: "",
        parentRatingKey: "",
        grandparentTitle: "",
        index: "",
        parentIndex: "",
        showDescription: "",
        isDiscover: false,
        isLiveContinue: true
    }
end function

function liveContinueRegistryKey(profileId as String) as String
    id = profileId
    if id = invalid or id = "" then id = "default"
    return "liveContinue_" + id
end function

function writeLiveContinueJson(key as String, json as String) as Boolean
    if key = "" or json = "" then return false
    section = CreateObject("roRegistrySection", "plexflix")
    if section = invalid then return false
    ok = section.Write(key, json)
    section.Flush()
    return ok = true
end function

function readLiveContinueJson(key as String) as String
    if key = "" then return ""
    section = CreateObject("roRegistrySection", "plexflix")
    if section = invalid then return ""
    if not section.Exists(key) then return ""
    return section.Read(key)
end function

function liveContinueStr(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    return ""
end function

function liveContinueInt(value as Dynamic) as Integer
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
        return Val(value)
    end if
    return 0
end function
