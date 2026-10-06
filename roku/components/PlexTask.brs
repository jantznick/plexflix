sub init()
    m.top.functionName = "exec"
end sub

sub exec()
    cfg = m.top.config
    if cfg = invalid then cfg = GetPlexConfig()

    action = m.top.action
    if action = "home" then
        m.top.response = buildHome(cfg)
    else if action = "resolvePlayable" then
        m.top.response = resolvePlayable(cfg, m.top.item)
    else if action = "randomEpisode" then
        m.top.response = fetchRandomEpisode(cfg, m.top.item)
    else if action = "children" then
        m.top.response = fetchChildren(cfg, m.top.item)
    else if action = "extras" then
        m.top.response = fetchExtras(cfg, m.top.item)
    else if action = "unavailableDetail" then
        m.top.response = fetchUnavailableDetail(cfg, m.top.item)
    else if action = "pinnedSources" then
        m.top.response = fetchPinnedSources(cfg)
    else if action = "sectionBrowse" then
        m.top.response = fetchSectionHub(cfg, m.top.item)
    else if action = "sectionAll" then
        m.top.response = fetchSectionAll(cfg, m.top.item)
    else if action = "sectionFirstCharacter" then
        m.top.response = fetchSectionFirstCharacter(cfg, m.top.item)
    else if action = "resolveEpisodeShow" then
        m.top.response = resolveEpisodeShow(cfg, m.top.item)
    else if action = "personDetail" then
        m.top.response = fetchPersonDetail(cfg, m.top.item)
    else if action = "liveTv" then
        m.top.response = fetchLiveTv(cfg)
    else if action = "liveTvGuide" then
        m.top.response = fetchLiveTvGuide(cfg)
    else if action = "liveTvGrid" then
        m.top.response = fetchLiveTvGrid(cfg, m.top.item)
    else if action = "dvrSchedule" then
        m.top.response = fetchDvrSchedule(cfg)
    else if action = "recordOptions" then
        m.top.response = fetchRecordOptions(cfg, m.top.item)
    else if action = "recordCreate" then
        m.top.response = createRecording(cfg, m.top.item)
    else if action = "recordCancel" then
        m.top.response = cancelRecording(cfg, m.top.item)
    else if action = "ruleSettings" then
        m.top.response = fetchRuleSettings(cfg, m.top.item)
    else if action = "ruleUpdate" then
        m.top.response = updateRecordingRule(cfg, m.top.item)
    else if action = "releaseLive" then
        m.top.response = releaseLiveSession(cfg, m.top.item)
    else if action = "tuneLiveChannel" then
        m.top.response = tuneLiveChannel(cfg, m.top.item)
    else if action = "sportsFeed" then
        m.top.response = fetchSportsFeed(cfg)
    else if action = "streamUrl" then
        m.top.response = buildStreamUrl(cfg, m.top.item)
    else if action = "reportProgress" then
        m.top.response = reportProgress(cfg, m.top.item)
    else if action = "scrobble" then
        m.top.response = scrobbleItem(cfg, m.top.item)
    else if action = "mediaStreams" then
        m.top.response = fetchMediaStreams(cfg, m.top.item)
    else if action = "selectStreams" then
        m.top.response = selectStreams(cfg, m.top.item)
    else if action = "stopTranscode" then
        m.top.response = stopTranscode(cfg, m.top.item)
    else
        m.top.response = { ok: false, error: "Unknown action: " + action }
    end if
end sub

' brs-engine/desktop: numbers often lack .toStr(); never call it blindly.
function safeToStr(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        return Str(value).Trim()
    end if
    if valueType = "Boolean" or valueType = "roBoolean" then
        if value = true then return "true"
        return "false"
    end if
    return ""
end function

function plexGet(cfg as Object, path as String) as Object
    url = cfg.baseUrl + path
    if path.Instr("?") > 0 then
        url = url + "&X-Plex-Token=" + cfg.token
    else
        url = url + "?X-Plex-Token=" + cfg.token
    end if

    ' Prefer JSON for simpler parsing on device
    if url.Instr("X-Plex-Container-Size") = 0 then
        url = url + "&X-Plex-Container-Size=" + safeToStr(cfg.rowSize)
    end if

    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(url)
    request.SetRequest("GET")
    request.EnableEncodings(true)
    request.RetainBodyOnError(true)
    request.AddHeader("Accept", "application/json")
    request.AddHeader("X-Plex-Token", cfg.token)
    request.AddHeader("X-Plex-Product", cfg.product)
    request.AddHeader("X-Plex-Version", cfg.version)
    request.AddHeader("X-Plex-Client-Identifier", cfg.clientId)
    request.AddHeader("X-Plex-Platform", "Roku")
    request.AddHeader("X-Plex-Device", "Roku")
    request.AddHeader("X-Plex-Provides", "player")

    ' Local Plex is often HTTP; HTTPS self-signed needs certs disabled carefully
    if Left(cfg.baseUrl, 8) = "https://" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if

    if not request.AsyncGetToString() then
        return { ok: false, error: "Failed to start request to " + path }
    end if

    while true
        msg = wait(15000, port)
        if msg = invalid then
            request.AsyncCancel()
            return { ok: false, error: "Timed out talking to Plex (" + path + ")" }
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            body = msg.GetString()
            if code < 200 or code >= 300 then
                return { ok: false, error: "Plex HTTP " + safeToStr(code) + " for " + path }
            end if
            parsed = ParseJson(body)
            if parsed = invalid then
                return { ok: false, error: "Could not parse Plex JSON for " + path }
            end if
            return { ok: true, json: parsed }
        end if
    end while
end function

function plexPost(cfg as Object, path as String, body = "" as String) as Object
    url = cfg.baseUrl + path
    if path.Instr("?") > 0 then
        url = url + "&X-Plex-Token=" + cfg.token
    else
        url = url + "?X-Plex-Token=" + cfg.token
    end if

    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(url)
    request.SetRequest("POST")
    request.EnableEncodings(true)
    request.RetainBodyOnError(true)
    request.AddHeader("Accept", "application/json")
    request.AddHeader("Content-Type", "application/x-www-form-urlencoded")
    request.AddHeader("X-Plex-Token", cfg.token)
    request.AddHeader("X-Plex-Product", cfg.product)
    request.AddHeader("X-Plex-Version", cfg.version)
    request.AddHeader("X-Plex-Client-Identifier", cfg.clientId)
    request.AddHeader("X-Plex-Platform", "Roku")
    request.AddHeader("X-Plex-Device", "Roku")
    request.AddHeader("X-Plex-Provides", "player")

    if Left(cfg.baseUrl, 8) = "https://" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if

    if not request.AsyncPostFromString(body) then
        return { ok: false, error: "Failed to start POST " + path }
    end if

    while true
        msg = wait(20000, port)
        if msg = invalid then
            request.AsyncCancel()
            return { ok: false, error: "Timed out on POST " + path }
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            respBody = msg.GetString()
            if code < 200 or code >= 300 then
                return { ok: false, error: "Plex HTTP " + safeToStr(code) + " for POST " + path }
            end if
            parsed = ParseJson(respBody)
            if parsed = invalid then
                ' Some tune responses are sparse; still return body for session parsing
                return { ok: true, json: invalid, body: respBody }
            end if
            return { ok: true, json: parsed, body: respBody }
        end if
    end while
end function

' Timeline, scrobble, part updates and transcode teardown answer with an empty
' or XML body, so they get a request path that never tries to parse JSON.
function plexCommand(cfg as Object, path as String, method as String) as Object
    url = cfg.baseUrl + path
    if path.Instr("?") > 0 then
        url = url + "&X-Plex-Token=" + cfg.token
    else
        url = url + "?X-Plex-Token=" + cfg.token
    end if

    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(url)
    request.SetRequest(method)
    request.EnableEncodings(true)
    request.RetainBodyOnError(true)
    request.AddHeader("X-Plex-Token", cfg.token)
    request.AddHeader("X-Plex-Product", cfg.product)
    request.AddHeader("X-Plex-Version", cfg.version)
    request.AddHeader("X-Plex-Client-Identifier", cfg.clientId)
    request.AddHeader("X-Plex-Platform", "Roku")
    request.AddHeader("X-Plex-Device", "Roku")
    request.AddHeader("X-Plex-Provides", "player")

    if Left(cfg.baseUrl, 8) = "https://" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if

    started = false
    if method = "GET" then
        started = request.AsyncGetToString()
    else
        started = request.AsyncPostFromString("")
    end if
    if not started then return { ok: false, error: "Failed to start " + method + " " + path }

    while true
        msg = wait(10000, port)
        if msg = invalid then
            request.AsyncCancel()
            return { ok: false, error: "Timed out on " + method + " " + path }
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            if code < 200 or code >= 300 then
                return { ok: false, error: "Plex HTTP " + safeToStr(code) + " for " + path }
            end if
            return { ok: true, body: msg.GetString() }
        end if
    end while
end function

' Without this the server never learns what was watched here: no Continue
' Watching entry, no resume point, no played flag.
function reportProgress(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No progress payload" }
    ratingKey = safeToStr(item.ratingKey)
    key = safeToStr(item.key)
    if ratingKey = "" or key = "" then return { ok: false, error: "Missing keys for timeline" }

    state = safeToStr(item.state)
    if state = "" then state = "playing"

    query = []
    query.push("ratingKey=" + ratingKey)
    query.push("key=" + requestEncode(key))
    query.push("identifier=com.plexapp.plugins.library")
    query.push("state=" + state)
    query.push("time=" + safeToStr(intOrZero(item.time)))
    query.push("duration=" + safeToStr(intOrZero(item.duration)))
    query.push("hasMDE=1")

    return plexCommand(cfg, "/:/timeline?" + joinStrings(query, "&"), "GET")
end function

function scrobbleItem(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No scrobble payload" }
    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing ratingKey for scrobble" }

    verb = "/:/scrobble"
    if item.unwatch = true then verb = "/:/unscrobble"
    path = verb + "?identifier=com.plexapp.plugins.library&key=" + ratingKey
    return plexCommand(cfg, path, "GET")
end function

function stopTranscode(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: true }
    session = safeToStr(item.session)
    if session = "" then return { ok: true }
    ' Leaves an orphaned ffmpeg on the server otherwise
    return plexCommand(cfg, "/video/:/transcode/universal/stop?session=" + requestEncode(session), "GET")
end function

function fetchMediaStreams(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }
    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing ratingKey" }

    ' includeMarkers brings back the intro / credits / commercial ranges Plex
    ' generates, so the player can offer a skip without a second request
    result = plexGet(cfg, "/library/metadata/" + ratingKey + "?includeMarkers=1")
    if result.ok <> true or result.json = invalid then return { ok: false, error: "Could not read media info" }
    container = result.json.MediaContainer
    if container = invalid then return { ok: false, error: "Could not read media info" }

    meta = container.Metadata
    if meta = invalid then return { ok: false, error: "Could not read media info" }
    if GetInterface(meta, "ifArray") <> invalid then
        if meta.count() = 0 then return { ok: false, error: "Could not read media info" }
        meta = meta[0]
    end if

    medias = meta.Media
    if medias = invalid then return { ok: false, error: "No media versions" }
    if GetInterface(medias, "ifArray") = invalid then medias = [medias]

    versions = []
    for i = 0 to medias.count() - 1
        versions.push({
            label: versionLabel(medias[i], i),
            mediaIndex: i
        })
    end for

    ' Streams live on the part, and the first part is the one we transcode
    audio = []
    subtitles = [{ id: 0, label: "Off", selected: true }]
    partId = ""
    previewUrlBase = ""
    parts = medias[0].Part
    if parts <> invalid then
        if GetInterface(parts, "ifArray") = invalid then parts = [parts]
        if parts.count() > 0 then
            partId = safeToStr(parts[0].id)
            ' indexes="sd" means the server has built a BIF preview index for
            ' this file, which is what makes scrubbing thumbnails possible
            if safeToStr(parts[0].indexes) = "sd" then
                previewUrlBase = cfg.baseUrl + "/library/parts/" + partId + "/indexes/sd/"
            end if
            streams = parts[0].Stream
            if streams <> invalid then
                if GetInterface(streams, "ifArray") = invalid then streams = [streams]
                for each stream in streams
                    streamType = 0
                    if stream.streamType <> invalid then streamType = stream.streamType
                    selected = (stream.selected = true or safeToStr(stream.selected) = "1")
                    entry = {
                        id: intOrZero(stream.id),
                        label: streamLabel(stream),
                        selected: selected
                    }
                    if streamType = 2 then
                        audio.push(entry)
                    else if streamType = 3 then
                        subtitles.push(entry)
                        if selected then subtitles[0].selected = false
                    end if
                end for
            end if
        end if
    end if

    return {
        ok: true,
        partId: partId,
        versions: versions,
        audio: audio,
        subtitles: subtitles,
        markers: extractMarkers(meta),
        previewUrlBase: previewUrlBase
    }
end function

function extractMarkers(meta as Object) as Object
    out = []
    if meta = invalid then return out

    markers = meta.Marker
    if markers = invalid then return out
    if GetInterface(markers, "ifArray") = invalid then markers = [markers]

    for each marker in markers
        kind = LCase(safeToStr(marker.type))
        label = markerLabel(kind)
        startAt = intOrZero(marker.startTimeOffset)
        endAt = intOrZero(marker.endTimeOffset)
        ' Plex occasionally emits zero-length or unlabelled markers
        if label <> "" and endAt > startAt then
            out.push({ kind: kind, startAt: startAt, endAt: endAt, label: label })
        end if
    end for
    return out
end function

function markerLabel(kind as String) as String
    if kind = "intro" then return "Skip Intro"
    if kind = "credits" then return "Skip Credits"
    if kind = "commercial" then return "Skip Ad"
    return ""
end function

function versionLabel(media as Object, index as Integer) as String
    bits = []
    resolution = safeToStr(media.videoResolution)
    if resolution <> "" then
        if Instr(1, resolution, "k") > 0 or Instr(1, resolution, "K") > 0 then
            bits.push(UCase(resolution))
        else
            bits.push(resolution + "p")
        end if
    end if
    codec = safeToStr(media.videoCodec)
    if codec <> "" then bits.push(UCase(codec))
    if media.bitrate <> invalid and media.bitrate > 0 then
        bits.push(safeToStr(Int(media.bitrate / 1000)) + " Mbps")
    end if
    if bits.count() = 0 then return "Version " + safeToStr(index + 1)
    return joinStrings(bits, " · ")
end function

function streamLabel(stream as Object) as String
    label = safeToStr(stream.displayTitle)
    if label <> "" then return label
    label = safeToStr(stream.extendedDisplayTitle)
    if label <> "" then return label

    bits = []
    language = safeToStr(stream.language)
    if language = "" then language = safeToStr(stream.languageCode)
    if language <> "" then bits.push(language)
    codec = safeToStr(stream.codec)
    if codec <> "" then bits.push(UCase(codec))
    if stream.channels <> invalid and stream.channels > 0 then
        bits.push(safeToStr(stream.channels) + " ch")
    end if
    if bits.count() = 0 then return "Track " + safeToStr(intOrZero(stream.id))
    return joinStrings(bits, " · ")
end function

function selectStreams(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No stream selection" }
    partId = safeToStr(item.partId)
    if partId = "" then return { ok: false, error: "Missing part id" }

    query = ["allParts=1"]
    if item.audioStreamID <> invalid then
        query.push("audioStreamID=" + safeToStr(intOrZero(item.audioStreamID)))
    end if
    if item.subtitleStreamID <> invalid then
        ' 0 turns subtitles off
        query.push("subtitleStreamID=" + safeToStr(intOrZero(item.subtitleStreamID)))
    end if

    return plexCommand(cfg, "/library/parts/" + partId + "?" + joinStrings(query, "&"), "PUT")
end function

function intOrZero(value as Dynamic) as Integer
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

function imageUrl(cfg as Object, path as Dynamic, width = 420 as Integer, height = 630 as Integer) as String
    if path = invalid or path = "" then return ""
    pathStr = safeToStr(path)
    if Left(pathStr, 4) = "http" then return pathStr
    ' minSize=1 = cover/crop (preserves aspect). upscale=0 avoids mushy blow-ups.
    return cfg.baseUrl + "/photo/:/transcode?width=" + safeToStr(width) + "&height=" + safeToStr(height) + "&minSize=1&upscale=0&url=" + requestEncode(pathStr) + "&X-Plex-Token=" + cfg.token
end function

function imageUrlWide(cfg as Object, path as Dynamic, width = 1920 as Integer) as String
    ' Width-only: Plex scales proportionally — no forced height that can look stretched
    if path = invalid or path = "" then return ""
    pathStr = safeToStr(path)
    if Left(pathStr, 4) = "http" then return pathStr
    return cfg.baseUrl + "/photo/:/transcode?width=" + safeToStr(width) + "&minSize=1&upscale=0&url=" + requestEncode(pathStr) + "&X-Plex-Token=" + cfg.token
end function

function requestEncode(value as String) as String
    transfer = CreateObject("roUrlTransfer")
    return transfer.Escape(value)
end function

' Rows can mix library metadata with hand-built live TV / sports entries that
' never went through metadataToItem, so normalise before handing to addFields
function watchedFlag(item as Object) as Boolean
    if item = invalid or item.watched <> true then return false
    return true
end function

function unwatchedTotal(item as Object) as Integer
    if item = invalid or item.unwatchedCount = invalid then return 0
    count = item.unwatchedCount
    if count < 0 then return 0
    return count
end function

function viewedLeaves(item as Object) as Integer
    if item = invalid or item.viewedLeafCount = invalid then return 0
    return item.viewedLeafCount
end function

function metadataToItem(cfg as Object, meta as Object) as Object
    if meta = invalid then return invalid

    mediaType = safeToStr(meta.type)

    thumb = ""
    art = ""
    if meta.thumb <> invalid then thumb = safeToStr(meta.thumb)
    if meta.art <> invalid then art = safeToStr(meta.art)

    ratingKey = safeToStr(meta.ratingKey)
    key = safeToStr(meta.key)
    rawTitle = safeToStr(meta.title)
    title = rawTitle

    ' Episodes: prefer grandparent/parent context in title for home shelves
    grandparentRatingKey = ""
    parentRatingKey = ""
    grandparentTitle = ""
    showThumb = ""
    if mediaType = "episode" then
        grandparentTitle = safeToStr(meta.grandparentTitle)
        grandparentRatingKey = safeToStr(meta.grandparentRatingKey)
        parentRatingKey = safeToStr(meta.parentRatingKey)
        season = safeToStr(meta.parentIndex)
        episode = safeToStr(meta.index)
        if grandparentTitle <> "" then
            title = grandparentTitle + " — S" + season + "E" + episode + " " + rawTitle
        end if
        if meta.grandparentThumb <> invalid then showThumb = safeToStr(meta.grandparentThumb)
        if showThumb <> "" and thumb = "" then thumb = showThumb
        ' Prefer show art for billboards — episode stills look stretched/weird at 16:9
        if meta.grandparentArt <> invalid and safeToStr(meta.grandparentArt) <> "" then
            art = safeToStr(meta.grandparentArt)
        else if grandparentRatingKey <> "" then
            ' Hub payloads often omit grandparentArt — synthesize the show art path
            art = "/library/metadata/" + grandparentRatingKey + "/art"
        end if
    end if

    ' Movies/shows with no art field: still request the metadata art endpoint
    if art = "" and ratingKey <> "" then
        art = "/library/metadata/" + ratingKey + "/art"
    end if

    description = safeToStr(meta.summary)
    year = safeToStr(meta.year)

    rating = ""
    if meta.audienceRating <> invalid then
        rating = safeToStr(meta.audienceRating)
    else if meta.rating <> invalid then
        rating = safeToStr(meta.rating)
    end if

    contentRating = safeToStr(meta.contentRating)

    duration = 0
    if meta.duration <> invalid then duration = meta.duration
    viewOffset = 0
    if meta.viewOffset <> invalid then viewOffset = meta.viewOffset

    ' Plex watched state: viewCount counts completed plays on a leaf (movie or
    ' episode), viewedLeafCount counts watched episodes under a show or season
    viewCount = 0
    if meta.viewCount <> invalid then viewCount = meta.viewCount
    viewedLeafCount = 0
    if meta.viewedLeafCount <> invalid then viewedLeafCount = meta.viewedLeafCount
    leafCount = 0
    if meta.leafCount <> invalid then leafCount = meta.leafCount
    lastViewedAt = 0
    if meta.lastViewedAt <> invalid then lastViewedAt = meta.lastViewedAt

    watched = false
    if mediaType = "show" or mediaType = "season" then
        watched = (leafCount > 0 and viewedLeafCount >= leafCount)
    else
        watched = (viewCount > 0 and viewOffset = 0)
    end if

    unwatchedCount = 0
    if leafCount > viewedLeafCount then unwatchedCount = leafCount - viewedLeafCount

    indexVal = ""
    parentIndexVal = ""
    if meta.index <> invalid then indexVal = safeToStr(meta.index)
    if meta.parentIndex <> invalid then parentIndexVal = safeToStr(meta.parentIndex)

    ' Seasons often arrive as "Season 1" already; if blank, synthesize
    if mediaType = "season" and title = "" and indexVal <> "" then
        title = "Season " + indexVal
        rawTitle = title
    end if

    posterW = 360
    posterH = 540
    if mediaType = "episode" then
        posterW = 480
        posterH = 270
    end if

    showPosterUrl = ""
    if showThumb <> "" then showPosterUrl = imageUrl(cfg, showThumb, 360, 540)

    return {
        title: title,
        shortTitle: rawTitle,
        description: description,
        year: year,
        rating: rating,
        contentRating: contentRating,
        mediaType: mediaType,
        ratingKey: ratingKey,
        key: key,
        hdPosterUrl: imageUrl(cfg, thumb, posterW, posterH),
        thumbPath: thumb,
        hdShowPosterUrl: showPosterUrl,
        hdBackdropUrl: imageUrl(cfg, art, 1920, 1080),
        showDescription: "",
        duration: duration,
        viewOffset: viewOffset,
        viewedLeafCount: viewedLeafCount,
        lastViewedAt: lastViewedAt,
        watched: watched,
        unwatchedCount: unwatchedCount,
        leafCount: leafCount,
        childCount: meta.childCount,
        index: indexVal,
        parentIndex: parentIndexVal,
        grandparentRatingKey: grandparentRatingKey,
        parentRatingKey: parentRatingKey,
        grandparentTitle: grandparentTitle
    }
end function

function preferShowPosters(items as Object) as Object
    ' Continue Watching: use the show/movie poster, not episode stills
    if items = invalid then return []
    for each item in items
        if item <> invalid and safeToStr(item.mediaType) = "episode" then
            showPoster = ""
            if item.DoesExist("hdShowPosterUrl") then showPoster = safeToStr(item.hdShowPosterUrl)
            if showPoster <> "" then item.hdPosterUrl = showPoster
            if safeToStr(item.grandparentTitle) <> "" then item.shortTitle = safeToStr(item.grandparentTitle)
        end if
    end for
    return items
end function

function enrichEpisodeShowDescriptions(cfg as Object, items as Object) as Object
    ' Hub/on-deck episodes only carry the episode synopsis. Home billboard should
    ' show the *show* synopsis — fetch each unique grandparent once and stamp it.
    if items = invalid then return []
    cache = {}
    for each item in items
        if item <> invalid and safeToStr(item.mediaType) = "episode" then
            showKey = safeToStr(item.grandparentRatingKey)
            if showKey <> "" then
                showSummary = ""
                if cache.DoesExist(showKey) then
                    showSummary = safeToStr(cache[showKey])
                else
                    result = plexGet(cfg, "/library/metadata/" + showKey)
                    if result.ok = true and result.json <> invalid and result.json.MediaContainer <> invalid then
                        meta = result.json.MediaContainer.Metadata
                        if meta = invalid then meta = result.json.MediaContainer.Directory
                        if meta <> invalid then
                            if GetInterface(meta, "ifArray") <> invalid and meta.count() > 0 then meta = meta[0]
                            if meta.summary <> invalid then showSummary = safeToStr(meta.summary)
                        end if
                    end if
                    cache[showKey] = showSummary
                end if
                item.showDescription = showSummary
            end if
        end if
    end for
    return items
end function

function clampRowItems(items as Object) as Object
    ' Only keep rows that can feel full: 15–30 items. Cap, then loop by duplicating.
    out = []
    if items = invalid then return out
    for each item in items
        if item <> invalid then out.push(item)
        if out.count() >= 30 then exit for
    end for
    if out.count() < 15 then return []

    ' Duplicate once so horizontal shelves feel continuous / looping
    looped = []
    for each item in out
        looped.push(item)
    end for
    for each item in out
        looped.push(item)
    end for
    return looped
end function

function appendRowNodes(root as Object, title as String, items as Object) as Boolean
    if items = invalid or items.count() = 0 then return false
    row = root.createChild("ContentNode")
    row.title = title
    for each item in items
        child = row.createChild("ContentNode")
        child.title = item.title
        child.description = item.description
        child.hdPosterUrl = item.hdPosterUrl
        ' Native ContentNode field — used by some SceneGraph widgets
        child.hdBackgroundImageUrl = item.hdBackdropUrl
        isDiscover = false
        if item.DoesExist("isDiscover") and item.isDiscover = true then isDiscover = true
        child.addFields({
            year: item.year,
            rating: item.rating,
            contentRating: item.contentRating,
            mediaType: item.mediaType,
            ratingKey: item.ratingKey,
            key: item.key,
            duration: item.duration,
            viewOffset: item.viewOffset,
            watched: watchedFlag(item),
            unwatchedCount: unwatchedTotal(item),
            viewedLeafCount: viewedLeaves(item),
            leafCount: item.leafCount,
            childCount: item.childCount,
            grandparentRatingKey: item.grandparentRatingKey,
            parentRatingKey: item.parentRatingKey,
            grandparentTitle: item.grandparentTitle,
            index: item.index,
            shortTitle: item.shortTitle,
            parentIndex: item.parentIndex,
            isDiscover: isDiscover,
            hdShowPosterUrl: item.hdShowPosterUrl,
            ' Custom field — must be in addFields or RowList drops it
            hdBackdropUrl: item.hdBackdropUrl,
            showDescription: item.showDescription
        })
    end for
    return true
end function

function appendRow(root as Object, title as String, items as Object) as Boolean
    ' Home shelves: enforce 15–30 + loop duplicates
    return appendRowNodes(root, title, clampRowItems(items))
end function

function collectMetadata(cfg as Object, container as Object) as Object
    items = []
    if container = invalid then return items
    metaList = invalid
    if container.Metadata <> invalid then
        metaList = container.Metadata
    else if container.MediaContainer <> invalid and container.MediaContainer.Metadata <> invalid then
        metaList = container.MediaContainer.Metadata
    end if
    if metaList = invalid then return items

    ' Plex may return a single object instead of an array
    if GetInterface(metaList, "ifArray") = invalid then
        metaList = [metaList]
    end if

    for each meta in metaList
        item = metadataToItem(cfg, meta)
        if item <> invalid then items.push(item)
    end for
    return items
end function

function buildHome(cfg as Object) as Object
    if cfg.token = invalid or cfg.token = "" or cfg.token = "REPLACE_WITH_YOUR_PLEX_TOKEN" then
        return { ok: false, error: "Set your Plex token in roku/source/PlexConfig.brs" }
    end if

    root = createObject("roSGNode", "ContentNode")
    seenTitles = {}
    movieSectionKeys = []
    showSectionKeys = []

    ' Continue Watching / On Deck — exempt from 15-min (always useful)
    onDeck = plexGet(cfg, "/library/onDeck")
    if onDeck.ok = true then
        addUniqueRowLoose(root, seenTitles, "Continue Watching", enrichEpisodeShowDescriptions(cfg, preferShowPosters(collectMetadata(cfg, onDeck.json))))
    end if

    ' Recently Added (global)
    recent = plexGet(cfg, "/library/recentlyAdded")
    if recent.ok = true then
        addUniqueRow(root, seenTitles, "Recently Added", collectMetadata(cfg, recent.json))
    end if

    ' Home hubs
    hubs = plexGet(cfg, "/hubs/home?count=" + safeToStr(cfg.rowSize))
    if hubs.ok = true and hubs.json <> invalid and hubs.json.MediaContainer <> invalid then
        appendHubRows(root, seenTitles, hubs.json.MediaContainer.Hub, cfg)
    end if

    ' Per-library hubs + collect section keys for genre shelves
    sections = plexGet(cfg, "/library/sections")
    if sections.ok = true and sections.json <> invalid and sections.json.MediaContainer <> invalid then
        dirs = sections.json.MediaContainer.Directory
        if dirs <> invalid then
            if GetInterface(dirs, "ifArray") = invalid then dirs = [dirs]
            for each dir in dirs
                sectionType = safeToStr(dir.type)
                if sectionType = "movie" or sectionType = "show" then
                    key = safeToStr(dir.key)
                    title = safeToStr(dir.title)
                    if sectionType = "movie" then movieSectionKeys.push(key)
                    if sectionType = "show" then showSectionKeys.push(key)

                    sectionHubs = plexGet(cfg, "/hubs/sections/" + key + "?count=" + safeToStr(cfg.rowSize))
                    if sectionHubs.ok = true and sectionHubs.json <> invalid and sectionHubs.json.MediaContainer <> invalid then
                        appendHubRows(root, seenTitles, sectionHubs.json.MediaContainer.Hub, cfg)
                    end if

                    allItems = plexGet(cfg, "/library/sections/" + key + "/all?sort=addedAt:desc")
                    if allItems.ok = true then
                        label = title
                        if sectionType = "movie" then label = title + " · Movies"
                        if sectionType = "show" then label = title + " · TV"
                        addUniqueRow(root, seenTitles, label, collectMetadata(cfg, allItems.json))
                    end if
                end if
            end for
        end if
    end if

    ' Netflix-style genre shelves from local libraries
    appendGenreRows(root, seenTitles, cfg, movieSectionKeys, showSectionKeys)

    ' Discover / trending (may include titles not in library)
    appendDiscoverRows(root, seenTitles, cfg)

    if root.getChildCount() = 0 then
        err = "No rows loaded from Plex."
        if onDeck.ok <> true and onDeck.error <> invalid then err = onDeck.error
        if recent.ok <> true and recent.error <> invalid then err = recent.error
        if sections.ok <> true and sections.error <> invalid then err = sections.error
        return { ok: false, error: err }
    end if

    shuffleHomeRows(root)

    return { ok: true, content: root }
end function

sub shuffleHomeRows(root as Object)
    count = root.getChildCount()
    if count <= 2 then return

    pinned = []
    others = []
    for i = 0 to count - 1
        row = root.getChild(i)
        if row <> invalid then
            title = LCase(safeToStr(row.title))
            if title = "continue watching" then
                pinned.push(row)
            else
                others.push(row)
            end if
        end if
    end for

    others = shuffleArray(others)

    while root.getChildCount() > 0
        root.removeChildIndex(0)
    end while

    for each row in pinned
        root.appendChild(row)
    end for
    for each row in others
        root.appendChild(row)
    end for
end sub

function shuffleArray(list as Object) as Object
    if list = invalid or list.count() <= 1 then return list
    arr = []
    for each x in list
        arr.push(x)
    end for
    n = arr.count()
    for i = n - 1 to 1 step -1
        ' Rnd(0) → float in [0,1); Rnd(n) → int 1..n
        j = Int(Rnd(0) * (i + 1))
        tmp = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
    end for
    return arr
end function

sub appendGenreRows(root as Object, seenTitles as Object, cfg as Object, movieKeys as Object, showKeys as Object)
    genres = [
        { title: "Romantic Comedy Movies", genre: "Comedy", section: "movie", extra: "Romance" },
        { title: "Action Movies", genre: "Action", section: "movie", extra: "" },
        { title: "Horror Movies", genre: "Horror", section: "movie", extra: "" },
        { title: "Sci-Fi Movies", genre: "Sci-Fi", section: "movie", extra: "" },
        { title: "Romance Movies", genre: "Romance", section: "movie", extra: "" },
        { title: "Drama Movies", genre: "Drama", section: "movie", extra: "" },
        { title: "Family Movies", genre: "Family", section: "movie", extra: "" },
        { title: "Thriller Movies", genre: "Thriller", section: "movie", extra: "" },
        { title: "Comedy TV", genre: "Comedy", section: "show", extra: "" },
        { title: "Drama TV", genre: "Drama", section: "show", extra: "" },
        { title: "Crime TV", genre: "Crime", section: "show", extra: "" },
        { title: "Reality TV", genre: "Reality", section: "show", extra: "" },
        { title: "Kids TV", genre: "Kids", section: "show", extra: "" }
    ]

    for each g in genres
        keys = movieKeys
        if g.section = "show" then keys = showKeys
        if keys <> invalid and keys.count() > 0 then
            merged = []
            seenKeys = {}
            for each sectionKey in keys
                path = "/library/sections/" + sectionKey + "/all?genre=" + requestEncode(g.genre) + "&sort=rating:desc"
                result = plexGet(cfg, path)
                if result.ok = true then
                    for each it in collectMetadata(cfg, result.json)
                        rk = safeToStr(it.ratingKey)
                        if rk = "" or seenKeys.DoesExist(rk) = false then
                            if rk <> "" then seenKeys[rk] = true
                            merged.push(it)
                        end if
                        if merged.count() >= 30 then exit for
                    end for
                end if
                if merged.count() >= 30 then exit for
            end for
            addUniqueRow(root, seenTitles, g.title, merged)
        end if
    end for
end sub

sub appendDiscoverRows(root as Object, seenTitles as Object, cfg as Object)
    ' Trending / popular from Plex Discover (works even when not in local library)
    discoverSources = [
        { title: "Most Watchlisted", path: "/hubs/sections/home/top_watchlisted?count=30&includeMeta=1" },
        { title: "Trending on Netflix", path: "/library/platforms/netflix/trend?count=30&includeMeta=1" },
        { title: "Trending on Disney+", path: "/library/platforms/disney-plus/trend?count=30&includeMeta=1" },
        { title: "Trending on Hulu", path: "/library/platforms/hulu/trend?count=30&includeMeta=1" },
        { title: "Trending on Prime Video", path: "/library/platforms/amazon-prime-video/trend?count=30&includeMeta=1" },
        { title: "Popular on Apple TV+", path: "/library/platforms/apple-tv-plus/platform-popular?count=30&includeMeta=1" },
        { title: "Romance", path: "/library/categories/romance?count=30&includeMeta=1&includeExternalMetadata=1" },
        { title: "Animation", path: "/library/categories/animation?count=30&includeMeta=1&includeExternalMetadata=1" },
        { title: "Comedy", path: "/library/categories/comedy?count=30&includeMeta=1&includeExternalMetadata=1" },
        { title: "Documentary", path: "/library/categories/documentary?count=30&includeMeta=1&includeExternalMetadata=1" }
    ]

    for each src in discoverSources
        result = discoverGet(cfg, src.path)
        if result.ok = true then
            items = collectDiscoverMetadata(cfg, result.json)
            addUniqueRow(root, seenTitles, src.title, items)
        end if
    end for
end sub

function discoverGet(cfg as Object, path as String) as Object
    url = "https://discover.provider.plex.tv" + path
    if path.Instr("?") > 0 then
        url = url + "&X-Plex-Token=" + cfg.token
    else
        url = url + "?X-Plex-Token=" + cfg.token
    end if
    url = url + "&X-Plex-Provider-Version=6.5&X-Plex-Language=en"

    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(url)
    request.SetRequest("GET")
    request.EnableEncodings(true)
    request.RetainBodyOnError(true)
    request.AddHeader("Accept", "application/json")
    request.AddHeader("X-Plex-Token", cfg.token)
    request.AddHeader("X-Plex-Product", cfg.product)
    request.AddHeader("X-Plex-Version", cfg.version)
    request.AddHeader("X-Plex-Client-Identifier", cfg.clientId)
    request.AddHeader("X-Plex-Platform", "Roku")
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()

    if not request.AsyncGetToString() then
        return { ok: false, error: "Failed discover request" }
    end if

    while true
        msg = wait(12000, port)
        if msg = invalid then
            request.AsyncCancel()
            return { ok: false, error: "Discover timeout" }
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            body = msg.GetString()
            if code < 200 or code >= 300 then
                return { ok: false, error: "Discover HTTP " + safeToStr(code) }
            end if
            parsed = ParseJson(body)
            if parsed = invalid then return { ok: false, error: "Discover parse error" }
            return { ok: true, json: parsed }
        end if
    end while
end function

function collectDiscoverMetadata(cfg as Object, container as Object) as Object
    items = collectMetadata(cfg, container)
    ' Also walk Hub → Metadata when present
    if items.count() = 0 and container <> invalid and container.MediaContainer <> invalid then
        hubs = container.MediaContainer.Hub
        if hubs <> invalid then
            if GetInterface(hubs, "ifArray") = invalid then hubs = [hubs]
            for each hub in hubs
                for each it in collectMetadata(cfg, hub)
                    items.push(it)
                    if items.count() >= 30 then exit for
                end for
                if items.count() >= 30 then exit for
            end for
        end if
    end if
    for each it in items
        it.isDiscover = true
        ' Discover items may lack a local ratingKey playable path — still browsable
        if safeToStr(it.mediaType) = "" then it.mediaType = "movie"
    end for
    return items
end function

sub appendHubRows(root as Object, seenTitles as Object, hubList as Dynamic, cfg as Object)
    if hubList = invalid then return
    if GetInterface(hubList, "ifArray") = invalid then hubList = [hubList]
    for each hub in hubList
        hubTitle = safeToStr(hub.title)
        if hubTitle = "" then hubTitle = "Browse"
        if hub.Metadata <> invalid then
            addUniqueRow(root, seenTitles, hubTitle, collectMetadata(cfg, hub))
        end if
    end for
end sub

sub addUniqueRow(root as Object, seenTitles as Object, title as String, items as Object)
    if items = invalid or items.count() = 0 then return
    key = LCase(title)
    if seenTitles.DoesExist(key) then return
    if appendRow(root, title, items) then
        seenTitles[key] = true
    end if
end sub

sub addUniqueRowLoose(root as Object, seenTitles as Object, title as String, items as Object)
    ' Continue Watching etc — show even with fewer than 15 items, still loop when possible
    if items = invalid or items.count() = 0 then return
    key = LCase(title)
    if seenTitles.DoesExist(key) then return

    capped = []
    for each item in items
        if item <> invalid then capped.push(item)
        if capped.count() >= 30 then exit for
    end for
    if capped.count() = 0 then return

    looped = []
    for each item in capped
        looped.push(item)
    end for
    if capped.count() >= 8 then
        for each item in capped
            looped.push(item)
        end for
    end if

    row = root.createChild("ContentNode")
    row.title = title
    for each item in looped
        child = row.createChild("ContentNode")
        child.title = item.title
        child.description = item.description
        child.hdPosterUrl = item.hdPosterUrl
        child.hdBackgroundImageUrl = item.hdBackdropUrl
        isDiscover = false
        if item.DoesExist("isDiscover") and item.isDiscover = true then isDiscover = true
        child.addFields({
            year: item.year,
            rating: item.rating,
            contentRating: item.contentRating,
            mediaType: item.mediaType,
            ratingKey: item.ratingKey,
            key: item.key,
            duration: item.duration,
            viewOffset: item.viewOffset,
            watched: watchedFlag(item),
            unwatchedCount: unwatchedTotal(item),
            viewedLeafCount: viewedLeaves(item),
            leafCount: item.leafCount,
            childCount: item.childCount,
            grandparentRatingKey: item.grandparentRatingKey,
            parentRatingKey: item.parentRatingKey,
            grandparentTitle: item.grandparentTitle,
            index: item.index,
            shortTitle: item.shortTitle,
            parentIndex: item.parentIndex,
            isDiscover: isDiscover,
            hdShowPosterUrl: item.hdShowPosterUrl,
            hdBackdropUrl: item.hdBackdropUrl,
            showDescription: item.showDescription
        })
    end for
    seenTitles[key] = true
end sub

function resolvePlayable(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }

    mediaType = ""
    if item.mediaType <> invalid then mediaType = item.mediaType

    if mediaType = "movie" or mediaType = "episode" then
        return { ok: true, item: item }
    end if

    ' Show -> whatever Plex says is next up, else first episode of first season
    if mediaType = "show" then
        onDeck = fetchOnDeck(cfg, safeToStr(item.ratingKey))
        if onDeck <> invalid then return { ok: true, item: onDeck }

        detail = plexGet(cfg, "/library/metadata/" + item.ratingKey + "/allLeaves?sort=index")
        if detail.ok = true then
            episodes = collectMetadata(cfg, detail.json)
            if episodes.count() > 0 then
                ' Resume a part-watched episode before falling back to the start
                for each ep in episodes
                    if ep.viewOffset <> invalid and ep.viewOffset > 0 then
                        return { ok: true, item: ep }
                    end if
                end for
                for each ep in episodes
                    if ep.watched <> true then return { ok: true, item: ep }
                end for
                return { ok: true, item: episodes[0] }
            end if
        end if
    end if

    if mediaType = "season" then
        kids = plexGet(cfg, "/library/metadata/" + item.ratingKey + "/children")
        if kids.ok = true then
            episodes = collectMetadata(cfg, kids.json)
            if episodes.count() > 0 then return { ok: true, item: episodes[0] }
        end if
    end if

    return { ok: false, error: "Could not find a playable episode" }
end function

function fetchRandomEpisode(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }

    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing show key" }

    mediaType = safeToStr(item.mediaType)
    path = "/library/metadata/" + ratingKey + "/allLeaves"
    if mediaType = "season" then path = "/library/metadata/" + ratingKey + "/children"

    result = plexGet(cfg, path)
    if result.ok <> true then
        err = "Could not load episodes"
        if result.error <> invalid then err = result.error
        return { ok: false, error: err }
    end if

    episodes = collectMetadata(cfg, result.json)
    if episodes.count() = 0 then return { ok: false, error: "No episodes to shuffle" }

    ' Seed once, then pick 1..count
    seed = Rnd(0)
    pick = episodes[Rnd(episodes.count()) - 1]
    return { ok: true, item: pick }
end function

' includeOnDeck makes the server pick the next episode: the part-watched one if
' there is one, otherwise the first unwatched in airing order.
function fetchOnDeck(cfg as Object, ratingKey as String) as Object
    if ratingKey = "" then return invalid

    result = plexGet(cfg, "/library/metadata/" + ratingKey + "?includeOnDeck=1")
    if result.ok <> true or result.json = invalid then return invalid
    container = result.json.MediaContainer
    if container = invalid then return invalid

    meta = container.Metadata
    if meta = invalid then return invalid
    if GetInterface(meta, "ifArray") <> invalid then
        if meta.count() = 0 then return invalid
        meta = meta[0]
    end if
    if meta.OnDeck = invalid then return invalid

    upNext = meta.OnDeck.Metadata
    if upNext = invalid then return invalid
    if GetInterface(upNext, "ifArray") <> invalid then
        if upNext.count() = 0 then return invalid
        upNext = upNext[0]
    end if

    return metadataToItem(cfg, upNext)
end function

function fetchChildren(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }
    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing ratingKey" }

    result = plexGet(cfg, "/library/metadata/" + ratingKey + "/children")
    if result.ok <> true then return result

    items = collectMetadata(cfg, result.json)
    return { ok: true, items: items }
end function

function rolesToCast(cfg as Object, meta as Object) as Object
    castItems = []
    if meta = invalid then return castItems

    roles = meta.Role
    if roles = invalid then return castItems
    if GetInterface(roles, "ifArray") = invalid then roles = [roles]

    for each role in roles
        name = ""
        if role.tag <> invalid then
            name = safeToStr(role.tag)
        else if role.role <> invalid then
            name = safeToStr(role.role)
        end if
        if name <> "" then
            thumb = ""
            if role.thumb <> invalid then thumb = safeToStr(role.thumb)
            personId = ""
            if role.id <> invalid then personId = safeToStr(role.id)
            if personId = "" and role.tagKey <> invalid then personId = safeToStr(role.tagKey)
            castItems.push({
                title: name,
                shortTitle: name,
                description: safeToStr(role.role),
                mediaType: "actor",
                ratingKey: personId,
                key: personId,
                personId: personId,
                hdPosterUrl: imageUrl(cfg, thumb, 300, 450),
                hdBackdropUrl: "",
                duration: 0,
                viewOffset: 0,
                year: "",
                rating: "",
                contentRating: "",
                index: "",
                parentIndex: ""
            })
        end if
    end for
    return castItems
end function

function fetchShowCast(cfg as Object, showKey as String) as Object
    if showKey = "" then return []
    result = plexGet(cfg, "/library/metadata/" + showKey)
    if result.ok <> true or result.json = invalid then return []
    container = result.json.MediaContainer
    if container = invalid then return []

    meta = container.Metadata
    if meta = invalid then return []
    if GetInterface(meta, "ifArray") <> invalid then
        if meta.count() = 0 then return []
        meta = meta[0]
    end if
    return rolesToCast(cfg, meta)
end function

function fetchExtras(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }
    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing ratingKey" }

    castItems = []
    similarItems = []
    onDeckKey = ""
    onDeckSeasonKey = ""

    ' One request covers the header refresh, the cast and next-up
    details = plexGet(cfg, "/library/metadata/" + ratingKey + "?includeOnDeck=1")
    if details.ok = true and details.json <> invalid and details.json.MediaContainer <> invalid then
        meta = details.json.MediaContainer.Metadata
        if meta <> invalid then
            if GetInterface(meta, "ifArray") <> invalid then
                if meta.count() > 0 then meta = meta[0]
            end if
            if meta.OnDeck <> invalid then
                upNext = meta.OnDeck.Metadata
                if upNext <> invalid and GetInterface(upNext, "ifArray") <> invalid then
                    if upNext.count() > 0 then upNext = upNext[0] else upNext = invalid
                end if
                if upNext <> invalid then
                    onDeckKey = safeToStr(upNext.ratingKey)
                    onDeckSeasonKey = safeToStr(upNext.parentRatingKey)
                end if
            end if
            castItems = rolesToCast(cfg, meta)
            ' Episodes usually only list guest stars, so borrow the series cast
            if castItems.count() = 0 and safeToStr(meta.grandparentRatingKey) <> "" then
                castItems = fetchShowCast(cfg, safeToStr(meta.grandparentRatingKey))
            end if
        end if
    end if

    similar = plexGet(cfg, "/library/metadata/" + ratingKey + "/similar")
    if similar.ok = true then
        similarItems = collectMetadata(cfg, similar.json)
    end if

    detail = invalid
    if details.ok = true then
        mapped = collectMetadata(cfg, details.json)
        if mapped.count() > 0 then detail = mapped[0]
    end if

    return {
        ok: true,
        cast: castItems,
        similar: similarItems,
        detail: detail,
        onDeckKey: onDeckKey,
        onDeckSeasonKey: onDeckSeasonKey
    }
end function

function fetchUnavailableDetail(cfg as Object, item as Object) as Object
    ' Titles from Plex Discover that aren't in the local library.
    if item = invalid then return { ok: false, error: "No item" }

    title = safeToStr(item.title)
    year = safeToStr(item.year)
    mediaType = safeToStr(item.mediaType)
    if mediaType = "" then mediaType = "movie"

    tmdbKey = ""
    if cfg.tmdbApiKey <> invalid then tmdbKey = safeToStr(cfg.tmdbApiKey)

    detail = {
        title: title,
        description: safeToStr(item.description),
        year: year,
        rating: safeToStr(item.rating),
        contentRating: safeToStr(item.contentRating),
        mediaType: mediaType,
        hdPosterUrl: safeToStr(item.hdPosterUrl),
        hdBackdropUrl: safeToStr(item.hdBackdropUrl),
        ratingKey: safeToStr(item.ratingKey),
        key: safeToStr(item.key),
        isDiscover: true,
        unavailable: true
    }

    castItems = []
    genreName = ""
    tmdbId = ""

    if tmdbKey <> "" and tmdbKey <> "REPLACE_WITH_TMDB_API_KEY" and title <> "" then
        tmdb = fetchTmdbTitle(tmdbKey, title, year, mediaType)
        if tmdb <> invalid then
            if tmdb.description <> "" then detail.description = tmdb.description
            if tmdb.hdPosterUrl <> "" then detail.hdPosterUrl = tmdb.hdPosterUrl
            if tmdb.hdBackdropUrl <> "" then detail.hdBackdropUrl = tmdb.hdBackdropUrl
            if tmdb.rating <> "" then detail.rating = tmdb.rating
            if tmdb.year <> "" then detail.year = tmdb.year
            if tmdb.contentRating <> "" then detail.contentRating = tmdb.contentRating
            if tmdb.mediaType <> "" then detail.mediaType = tmdb.mediaType
            if tmdb.genreName <> "" then genreName = tmdb.genreName
            if tmdb.tmdbId <> "" then tmdbId = tmdb.tmdbId
            if tmdb.cast <> invalid then castItems = tmdb.cast
        end if
    end if

    similarItems = searchLocalSimilar(cfg, title, genreName, mediaType)

    return {
        ok: true,
        unavailable: true,
        detail: detail,
        cast: castItems,
        similar: similarItems,
        tmdbId: tmdbId
    }
end function

function fetchTmdbTitle(apiKey as String, title as String, year as String, mediaType as String) as Object
    isShow = (mediaType = "show" or mediaType = "tv" or mediaType = "series")
    kind = "movie"
    if isShow then kind = "tv"

    searchUrl = "https://api.themoviedb.org/3/search/" + kind + "?api_key=" + apiKey + "&query=" + requestEncode(title)
    if year <> "" then
        if isShow then
            searchUrl = searchUrl + "&first_air_date_year=" + year
        else
            searchUrl = searchUrl + "&year=" + year
        end if
    end if

    search = httpGetJson(searchUrl)
    if search = invalid or search.results = invalid or search.results.count() = 0 then
        ' Retry without year if the first pass missed
        if year <> "" then
            searchUrl = "https://api.themoviedb.org/3/search/" + kind + "?api_key=" + apiKey + "&query=" + requestEncode(title)
            search = httpGetJson(searchUrl)
        end if
    end if
    if search = invalid or search.results = invalid or search.results.count() = 0 then
        ' Flip movie/tv once if type was wrong
        other = "tv"
        if isShow then other = "movie"
        searchUrl = "https://api.themoviedb.org/3/search/" + other + "?api_key=" + apiKey + "&query=" + requestEncode(title)
        search = httpGetJson(searchUrl)
        if search <> invalid and search.results <> invalid and search.results.count() > 0 then
            kind = other
            isShow = (kind = "tv")
        end if
    end if
    if search = invalid or search.results = invalid or search.results.count() = 0 then return invalid

    hit = search.results[0]
    tmdbId = safeToStr(hit.id)
    if tmdbId = "" then return invalid

    detailUrl = "https://api.themoviedb.org/3/" + kind + "/" + tmdbId + "?api_key=" + apiKey + "&append_to_response=credits,content_ratings,release_dates"
    detail = httpGetJson(detailUrl)
    if detail = invalid then return invalid

    overview = safeToStr(detail.overview)
    rating = ""
    if detail.vote_average <> invalid then
        rating = Left(safeToStr(detail.vote_average), 3)
    end if
    outYear = year
    if isShow then
        outYear = Left(safeToStr(detail.first_air_date), 4)
    else
        outYear = Left(safeToStr(detail.release_date), 4)
    end if

    poster = ""
    backdrop = ""
    if detail.poster_path <> invalid and safeToStr(detail.poster_path) <> "" then
        poster = "https://image.tmdb.org/t/p/w500" + safeToStr(detail.poster_path)
    end if
    if detail.backdrop_path <> invalid and safeToStr(detail.backdrop_path) <> "" then
        backdrop = "https://image.tmdb.org/t/p/w1280" + safeToStr(detail.backdrop_path)
    end if

    genreName = ""
    if detail.genres <> invalid and detail.genres.count() > 0 then
        genreName = safeToStr(detail.genres[0].name)
    end if

    contentRating = ""
    ' Best-effort US rating
    if isShow and detail.content_ratings <> invalid and detail.content_ratings.results <> invalid then
        for each r in detail.content_ratings.results
            if safeToStr(r.iso_3166_1) = "US" and r.rating <> invalid then
                contentRating = safeToStr(r.rating)
                exit for
            end if
        end for
    else if detail.release_dates <> invalid and detail.release_dates.results <> invalid then
        for each r in detail.release_dates.results
            if safeToStr(r.iso_3166_1) = "US" and r.release_dates <> invalid then
                for each d in r.release_dates
                    if d.certification <> invalid and safeToStr(d.certification) <> "" then
                        contentRating = safeToStr(d.certification)
                        exit for
                    end if
                end for
            end if
            if contentRating <> "" then exit for
        end for
    end if

    castItems = []
    if detail.credits <> invalid and detail.credits.cast <> invalid then
        castList = detail.credits.cast
        if GetInterface(castList, "ifArray") = invalid then castList = [castList]
        maxN = castList.count()
        if maxN > 16 then maxN = 16
        for i = 0 to maxN - 1
            c = castList[i]
            if c <> invalid then
                name = safeToStr(c.name)
                if name <> "" then
                    thumb = ""
                    if c.profile_path <> invalid and safeToStr(c.profile_path) <> "" then
                        thumb = "https://image.tmdb.org/t/p/w342" + safeToStr(c.profile_path)
                    end if
                    castItems.push({
                        title: name,
                        shortTitle: name,
                        description: safeToStr(c.character),
                        mediaType: "actor",
                        ratingKey: "",
                        key: "",
                        personId: "",
                        hdPosterUrl: thumb,
                        hdBackdropUrl: "",
                        duration: 0,
                        viewOffset: 0,
                        year: "",
                        rating: "",
                        contentRating: "",
                        index: "",
                        parentIndex: ""
                    })
                end if
            end if
        end for
    end if

    outType = "movie"
    if isShow then outType = "show"

    return {
        title: title,
        description: overview,
        year: outYear,
        rating: rating,
        contentRating: contentRating,
        mediaType: outType,
        hdPosterUrl: poster,
        hdBackdropUrl: backdrop,
        genreName: genreName,
        tmdbId: tmdbId,
        cast: castItems
    }
end function

function searchLocalSimilar(cfg as Object, title as String, genreName as String, mediaType as String) as Object
    ' Pull in-library titles that feel related — genre search first, then fuzzy title.
    out = []
    seen = {}
    preferType = safeToStr(mediaType)
    if preferType = "series" or preferType = "tv" then preferType = "show"

    queries = []
    if genreName <> "" then queries.push(genreName)
    ' Use a significant word from the title as a soft related search
    word = firstSearchWord(title)
    if word <> "" then queries.push(word)
    if title <> "" then queries.push(title)

    for each q in queries
        if out.count() >= 24 then exit for
        result = plexGet(cfg, "/hubs/search?query=" + requestEncode(q) + "&limit=25")
        if result.ok = true then
            bucket = []
            for each it in collectSearchLibraryItems(cfg, result.json)
                rk = safeToStr(it.ratingKey)
                if rk = "" then rk = safeToStr(it.title)
                if seen.DoesExist(rk) = false then
                    if LCase(safeToStr(it.title)) <> LCase(title) then
                        seen[rk] = true
                        bucket.push(it)
                    end if
                end if
            end for
            ' Prefer same media type first so movie shelves don't drown in shows (and vice versa)
            if preferType <> "" then
                for each it in bucket
                    if safeToStr(it.mediaType) = preferType then
                        out.push(it)
                        if out.count() >= 24 then exit for
                    end if
                end for
            end if
            for each it in bucket
                if out.count() >= 24 then exit for
                already = false
                for each existing in out
                    if safeToStr(existing.ratingKey) = safeToStr(it.ratingKey) then
                        already = true
                        exit for
                    end if
                end for
                if already = false then out.push(it)
            end for
        end if
    end for
    return out
end function

function firstSearchWord(title as String) as String
    if title = "" then return ""
    parts = title.Tokenize(" ")
    if parts = invalid or parts.count() = 0 then return ""
    for each p in parts
        w = LCase(safeToStr(p))
        if Len(w) >= 4 then
            if w <> "the" and w <> "and" and w <> "with" and w <> "from" then
                return safeToStr(p)
            end if
        end if
    end for
    return safeToStr(parts[0])
end function

function collectSearchLibraryItems(cfg as Object, json as Object) as Object
    items = []
    if json = invalid or json.MediaContainer = invalid then return items
    hubs = json.MediaContainer.Hub
    if hubs = invalid then
        return collectMetadata(cfg, json)
    end if
    if GetInterface(hubs, "ifArray") = invalid then hubs = [hubs]
    for each hub in hubs
        hubType = safeToStr(hub.type)
        hubTitle = LCase(safeToStr(hub.title))
        keep = false
        if hubType = "movie" or hubType = "show" then keep = true
        if Instr(1, hubTitle, "movie") > 0 then keep = true
        if Instr(1, hubTitle, "show") > 0 then keep = true
        if Instr(1, hubTitle, "tv") > 0 then keep = true
        if keep then
            for each it in collectMetadata(cfg, hub)
                mt = safeToStr(it.mediaType)
                if mt = "movie" or mt = "show" then
                    it.isDiscover = false
                    items.push(it)
                end if
                if items.count() >= 30 then exit for
            end for
        end if
        if items.count() >= 30 then exit for
    end for
    return items
end function

function sectionIdFromKey(key as String) as String
    if key = "" then return ""
    marker = "/library/sections/"
    idx = Instr(1, key, marker)
    if idx > 0 then
        ' Keys arrive as /library/sections/4 and /library/sections/4/all?...
        rest = Mid(key, idx + Len(marker))
        for i = 1 to Len(rest)
            ch = Mid(rest, i, 1)
            if ch = "/" or ch = "?" then return Left(rest, i - 1)
        end for
        return rest
    end if
    lastSlash = 0
    for i = 1 to Len(key)
        if Mid(key, i, 1) = "/" then lastSlash = i
    end for
    if lastSlash > 0 and lastSlash < Len(key) then return Mid(key, lastSlash + 1)
    return key
end function

function fetchPinnedSources(cfg as Object) as Object
    ' Plex sidebar pins are client-side; server exposes libraries via /library/sections
    result = plexGet(cfg, "/library/sections")
    if result.ok <> true then return result

    items = []
    container = result.json
    dirs = invalid
    if container <> invalid and container.MediaContainer <> invalid then
        dirs = container.MediaContainer.Directory
    end if
    if dirs = invalid then return { ok: true, items: [] }
    if GetInterface(dirs, "ifArray") = invalid then dirs = [dirs]

    for each dir in dirs
        sectionType = safeToStr(dir.type)
        if sectionType = "movie" or sectionType = "show" then
            key = safeToStr(dir.key)
            sectionId = sectionIdFromKey(key)
            if sectionId <> "" then
                thumb = ""
                if dir.thumb <> invalid then thumb = safeToStr(dir.thumb)
                art = ""
                if dir.art <> invalid then art = safeToStr(dir.art)
                items.push({
                    title: safeToStr(dir.title),
                    mediaType: "library",
                    sectionType: sectionType,
                    sectionId: sectionId,
                    key: key,
                    ratingKey: sectionId,
                    description: safeToStr(dir.summary),
                    hdPosterUrl: imageUrl(cfg, thumb, 360, 540),
                    hdBackdropUrl: imageUrl(cfg, art, 1920, 1080),
                    childCount: dir.count
                })
            end if
        end if
    end for
    return { ok: true, items: items }
end function

function fetchSectionHub(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No library" }
    sectionId = safeToStr(item.sectionId)
    if sectionId = "" then sectionId = sectionIdFromKey(safeToStr(item.key))
    if sectionId = "" then return { ok: false, error: "Missing library section id" }

    title = safeToStr(item.title)
    if title = "" then title = "Library"
    sectionType = safeToStr(item.sectionType)

    heroPosters = []
    pool = []
    sample = plexGet(cfg, "/library/sections/" + sectionId + "/all?sort=addedAt:desc&X-Plex-Container-Start=0&X-Plex-Container-Size=48")
    if sample.ok = true then pool = collectMetadata(cfg, sample.json)
    heroPosters = pickRandomPosterUrls(cfg, pool, 24, 200, 300)

    root = createObject("roSGNode", "ContentNode")
    seenTitles = {}

    ' Continue Watching is always the first shelf under View all
    onDeck = plexGet(cfg, "/library/sections/" + sectionId + "/onDeck")
    if onDeck.ok = true then
        addUniqueRowLoose(root, seenTitles, "Continue Watching", enrichEpisodeShowDescriptions(cfg, preferShowPosters(collectMetadata(cfg, onDeck.json))))
    end if

    recent = plexGet(cfg, "/library/sections/" + sectionId + "/recentlyAdded")
    if recent.ok = true then
        addUniqueRowLoose(root, seenTitles, "Recently Added", collectMetadata(cfg, recent.json))
    end if

    hubs = plexGet(cfg, "/hubs/sections/" + sectionId + "?count=" + safeToStr(cfg.rowSize))
    if hubs.ok = true and hubs.json <> invalid and hubs.json.MediaContainer <> invalid then
        hubList = hubs.json.MediaContainer.Hub
        if hubList <> invalid then
            if GetInterface(hubList, "ifArray") = invalid then hubList = [hubList]
            for each hub in hubList
                hubTitle = safeToStr(hub.title)
                if hubTitle = "" then hubTitle = "Browse"
                low = LCase(hubTitle)
                skipHub = false
                if low = "continue watching" or low = "on deck" or low = "recently added" then skipHub = true
                if Left(low, 18) = "continue watching" then skipHub = true
                if hub.Metadata <> invalid and skipHub <> true then
                    addUniqueRowLoose(root, seenTitles, hubTitle, collectMetadata(cfg, hub))
                end if
            end for
        end if
    end if

    genres = collectSectionGenres(cfg, sectionId)

    if root.getChildCount() = 0 and heroPosters.count() = 0 then
        return { ok: false, error: "No titles found in " + title }
    end if
    return {
        ok: true,
        content: root,
        title: title,
        sectionId: sectionId,
        sectionType: sectionType,
        heroPosters: heroPosters,
        genres: genres
    }
end function

function sectionAllQuery(sectionId as String, item as Object) as Object
    genre = safeToStr(item.genre)
    genreId = safeToStr(item.genreId)
    search = safeToStr(item.search)
    sortKey = safeToStr(item.sort)
    if sortKey = "" then sortKey = "titleSort"
    decade = safeToStr(item.decade)
    unwatched = (item.unwatched = true)

    startAt = 0
    if item.start <> invalid then startAt = item.start
    if startAt < 0 then startAt = 0
    pageSize = 48
    if item.pageSize <> invalid then pageSize = item.pageSize
    if pageSize < 1 then pageSize = 48
    if pageSize > 120 then pageSize = 120

    ' Plex needs an explicit metadata type or section filters are ignored
    sectionType = safeToStr(item.sectionType)
    typeParam = ""
    if sectionType = "movie" then
        typeParam = "1"
    else if sectionType = "show" then
        typeParam = "2"
    end if

    path = "/library/sections/" + sectionId + "/all?sort=" + requestEncode(sortKey)
    if typeParam <> "" then path = path + "&type=" + typeParam
    path = path + "&X-Plex-Container-Start=" + safeToStr(startAt)
    path = path + "&X-Plex-Container-Size=" + safeToStr(pageSize)
    ' Tag filters (genre) must use the tag id, not its label
    if genreId <> "" then
        path = path + "&genre=" + requestEncode(genreId)
    else if genre <> "" and genre <> "All" then
        path = path + "&genre=" + requestEncode(genre)
    end if
    if search <> "" then
        ' "title=" is a contains match on the Plex filter API
        path = path + "&title=" + requestEncode(search)
    end if

    ' Filters that some library types reject outright — kept separate so a 4xx
    ' can be retried without them instead of leaving the grid empty
    extra = ""
    if decade <> "" and decade <> "All" then
        decadeStart = Int(Val(decade))
        if decadeStart > 1900 then
            ' Comma separated values are OR'd; repeating &year= would AND them
            years = ""
            for y = decadeStart to decadeStart + 9
                if years <> "" then years = years + ","
                years = years + safeToStr(y)
            end for
            extra = extra + "&year=" + years
        end if
    end if
    if unwatched then extra = extra + "&unwatched=1"

    return {
        path: path,
        extra: extra,
        sort: sortKey,
        start: startAt,
        pageSize: pageSize,
        genre: genre,
        genreId: genreId,
        search: search,
        decade: decade,
        unwatched: unwatched
    }
end function

function fetchSectionAll(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No library" }
    sectionId = safeToStr(item.sectionId)
    if sectionId = "" then sectionId = sectionIdFromKey(safeToStr(item.key))
    if sectionId = "" then return { ok: false, error: "Missing library section id" }

    title = safeToStr(item.title)
    if title = "" then title = "Library"

    query = sectionAllQuery(sectionId, item)
    path = query.path
    extra = query.extra
    startAt = query.start
    pageSize = query.pageSize

    warning = ""
    result = plexGet(cfg, path + extra)
    if result.ok <> true and extra <> "" then
        result = plexGet(cfg, path)
        if result.ok = true then warning = "Your server ignored the year / unwatched filter"
    end if
    if result.ok <> true then return result

    totalSize = 0
    if result.json <> invalid and result.json.MediaContainer <> invalid then
        if result.json.MediaContainer.totalSize <> invalid then
            totalSize = result.json.MediaContainer.totalSize
        else if result.json.MediaContainer.size <> invalid then
            totalSize = result.json.MediaContainer.size
        end if
    end if

    items = collectMetadata(cfg, result.json)
    grid = createObject("roSGNode", "ContentNode")
    for each it in items
        child = grid.createChild("ContentNode")
        child.title = it.title
        child.description = it.description
        child.hdPosterUrl = it.hdPosterUrl
        child.hdBackgroundImageUrl = it.hdBackdropUrl
        child.addFields({
            year: it.year,
            rating: it.rating,
            contentRating: it.contentRating,
            mediaType: it.mediaType,
            ratingKey: it.ratingKey,
            key: it.key,
            duration: it.duration,
            viewOffset: it.viewOffset,
            watched: watchedFlag(it),
            unwatchedCount: unwatchedTotal(it),
            viewedLeafCount: viewedLeaves(it),
            leafCount: it.leafCount,
            shortTitle: it.shortTitle,
            hdBackdropUrl: it.hdBackdropUrl
        })
    end for

    nextStart = startAt + items.count()
    hasMore = false
    if totalSize > 0 then
        hasMore = nextStart < totalSize
    else
        hasMore = items.count() >= pageSize
    end if

    return {
        ok: true,
        content: grid,
        title: title,
        sectionId: sectionId,
        count: items.count(),
        totalSize: totalSize,
        start: startAt,
        nextStart: nextStart,
        hasMore: hasMore,
        pageSize: pageSize,
        genre: query.genre,
        genreId: query.genreId,
        search: query.search,
        sort: query.sort,
        decade: query.decade,
        unwatched: query.unwatched,
        warning: warning,
        requestId: safeToStr(item.requestId)
    }
end function

function fetchSectionFirstCharacter(cfg as Object, item as Object) as Object
    ' /firstCharacter reports how many titles start with each letter, in the
    ' library's title order. Running totals turn that into grid offsets, which
    ' is what lets the A-Z rail jump straight into the middle of a big library.
    if item = invalid then return { ok: false, error: "No library" }
    sectionId = safeToStr(item.sectionId)
    if sectionId = "" then sectionId = sectionIdFromKey(safeToStr(item.key))
    if sectionId = "" then return { ok: false, error: "Missing library section id" }

    sectionType = safeToStr(item.sectionType)
    path = "/library/sections/" + sectionId + "/firstCharacter"
    if sectionType = "movie" then
        path = path + "?type=1"
    else if sectionType = "show" then
        path = path + "?type=2"
    end if

    result = plexGet(cfg, path)
    if result.ok <> true then return result
    if result.json = invalid or result.json.MediaContainer = invalid then
        return { ok: false, error: "No letters reported" }
    end if

    list = result.json.MediaContainer.Directory
    if list = invalid then list = []
    if GetInterface(list, "ifArray") = invalid then list = [list]

    letters = firstCharacterLetters(list)
    total = 0
    if letters.count() > 0 then
        last = letters[letters.count() - 1]
        total = last.offset + last.size
    end if
    return { ok: true, letters: letters, total: total }
end function

function firstCharacterLetters(list as Object) as Object
    letters = []
    offset = 0
    for each dir in list
        label = safeToStr(dir.title)
        if label = "" then label = safeToStr(dir.key)
        size = 0
        if dir.size <> invalid then size = dir.size
        if size > 0 then
            letters.push({ letter: normalizeFirstCharacter(label), offset: offset, size: size })
            offset = offset + size
        end if
    end for
    return letters
end function

function normalizeFirstCharacter(label as String) as String
    ' Plex buckets digits and symbols under "#"; anything else is a single letter
    if Len(label) <> 1 then return "#"
    upper = UCase(label)
    if Instr(1, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", upper) = 0 then return "#"
    return upper
end function

function collectSectionGenres(cfg as Object, sectionId as String) as Object
    genres = []
    result = plexGet(cfg, "/library/sections/" + sectionId + "/genre?X-Plex-Container-Start=0&X-Plex-Container-Size=200")
    if result.ok <> true or result.json = invalid then return genres
    container = result.json.MediaContainer
    if container = invalid then return genres
    list = container.Directory
    if list = invalid then return genres
    if GetInterface(list, "ifArray") = invalid then list = [list]
    for each g in list
        label = safeToStr(g.title)
        if label = "" then label = safeToStr(g.tag)
        id = genreIdFromDirectory(g)
        if label <> "" then genres.push({ title: label, id: id })
    end for
    return genres
end function

function genreIdFromDirectory(dir as Object) as String
    ' /library/sections/N/genre returns key="23" (sometimes a fastKey URL instead)
    id = safeToStr(dir.key)
    if id <> "" and Instr(1, id, "=") = 0 and Instr(1, id, "/") = 0 then return id

    candidates = [safeToStr(dir.fastKey), id]
    for each candidate in candidates
        marker = "genre="
        at = Instr(1, candidate, marker)
        if at > 0 then
            value = Mid(candidate, at + Len(marker))
            amp = Instr(1, value, "&")
            if amp > 0 then value = Left(value, amp - 1)
            if value <> "" then return value
        end if
    end for
    return ""
end function

function pickRandomPosterUrls(cfg as Object, items as Object, maxCount as Integer, width = 240 as Integer, height = 360 as Integer) as Object
    ' Mosaic tiles render small — ask Plex for small transcodes so the hero stays light
    urls = []
    if items = invalid or items.count() = 0 then return urls
    shuffled = shuffleArray(items)
    for each it in shuffled
        url = ""
        thumbPath = safeToStr(it.thumbPath)
        if thumbPath <> "" then url = imageUrl(cfg, thumbPath, width, height)
        if url = "" then url = safeToStr(it.hdPosterUrl)
        if url <> "" then urls.push(url)
        if urls.count() >= maxCount then exit for
    end for
    return urls
end function

function resolveEpisodeShow(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No episode" }
    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing episode ratingKey" }

    result = plexGet(cfg, "/library/metadata/" + ratingKey)
    if result.ok <> true then return result

    episodes = collectMetadata(cfg, result.json)
    if episodes.count() = 0 then return { ok: false, error: "Episode metadata missing" }
    ep = episodes[0]

    showKey = safeToStr(ep.grandparentRatingKey)
    if showKey = "" then return { ok: false, error: "Episode has no parent show" }

    showMeta = plexGet(cfg, "/library/metadata/" + showKey)
    if showMeta.ok <> true then return showMeta
    shows = collectMetadata(cfg, showMeta.json)
    if shows.count() = 0 then return { ok: false, error: "Show metadata missing" }

    return {
        ok: true,
        show: shows[0],
        focusEpisodeKey: safeToStr(ep.ratingKey),
        focusSeasonKey: safeToStr(ep.parentRatingKey)
    }
end function

function fetchPersonDetail(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No person" }
    name = safeToStr(item.title)
    personId = safeToStr(item.personId)
    if personId = "" then personId = safeToStr(item.ratingKey)

    credits = []
    bio = safeToStr(item.description)
    poster = safeToStr(item.hdPosterUrl)
    backdrop = ""
    metaLine = ""
    knownFor = ""

    ' Plex people endpoint (when id is available)
    if personId <> "" then
        plexPerson = plexGet(cfg, "/library/people/" + personId + "/media")
        if plexPerson.ok = true then
            credits = collectMetadata(cfg, plexPerson.json)
        end if
        plexMeta = plexGet(cfg, "/library/people/" + personId)
        if plexMeta.ok = true and plexMeta.json <> invalid and plexMeta.json.MediaContainer <> invalid then
            meta = plexMeta.json.MediaContainer.Directory
            if meta = invalid then meta = plexMeta.json.MediaContainer.Metadata
            if meta <> invalid then
                if GetInterface(meta, "ifArray") <> invalid and meta.count() > 0 then meta = meta[0]
                if meta.summary <> invalid and safeToStr(meta.summary) <> "" then bio = safeToStr(meta.summary)
                if meta.thumb <> invalid then poster = imageUrl(cfg, safeToStr(meta.thumb), 400, 600)
                if meta.art <> invalid then backdrop = imageUrl(cfg, safeToStr(meta.art), 1920, 1080)
            end if
        end if
    end if

    ' Optional TMDB enrichment — always prefers richer bios / filmography
    tmdbKey = ""
    if cfg.tmdbApiKey <> invalid then tmdbKey = safeToStr(cfg.tmdbApiKey)
    if tmdbKey <> "" and tmdbKey <> "REPLACE_WITH_TMDB_API_KEY" and name <> "" then
        tmdb = fetchTmdbPerson(tmdbKey, name)
        if tmdb <> invalid then
            if tmdb.bio <> "" then bio = tmdb.bio
            if tmdb.poster <> "" then poster = tmdb.poster
            if tmdb.backdrop <> "" then backdrop = tmdb.backdrop
            if tmdb.metaLine <> "" then metaLine = tmdb.metaLine
            if tmdb.knownFor <> "" then knownFor = tmdb.knownFor
            if tmdb.credits <> invalid and tmdb.credits.count() > 0 then
                ' Merge: plex library matches first, then TMDB titles not already present
                merged = []
                seen = {}
                for each c in credits
                    t = LCase(safeToStr(c.title))
                    if t <> "" then seen[t] = true
                    merged.push(c)
                end for
                for each c in tmdb.credits
                    t = LCase(safeToStr(c.title))
                    if t <> "" and seen.DoesExist(t) = false then
                        seen[t] = true
                        merged.push(c)
                    end if
                end for
                credits = merged
            end if
        end if
    end if

    movies = []
    shows = []
    for each c in credits
        mt = safeToStr(c.mediaType)
        if mt = "show" or mt = "tv" then
            shows.push(c)
        else
            movies.push(c)
        end if
    end for

    return {
        ok: true,
        person: {
            title: name,
            description: bio,
            metaLine: metaLine,
            knownFor: knownFor,
            hdPosterUrl: poster,
            hdBackdropUrl: backdrop,
            mediaType: "actor",
            personId: personId
        },
        credits: credits,
        movies: movies,
        shows: shows
    }
end function

function fetchTmdbPerson(apiKey as String, name as String) as Object
    searchUrl = "https://api.themoviedb.org/3/search/person?api_key=" + apiKey + "&query=" + requestEncode(name)
    search = httpGetJson(searchUrl)
    if search = invalid or search.results = invalid or search.results.count() = 0 then return invalid

    person = search.results[0]
    personId = safeToStr(person.id)
    if personId = "" then return invalid

    detailUrl = "https://api.themoviedb.org/3/person/" + personId + "?api_key=" + apiKey
    detail = httpGetJson(detailUrl)

    creditsUrl = "https://api.themoviedb.org/3/person/" + personId + "/combined_credits?api_key=" + apiKey
    creditsJson = httpGetJson(creditsUrl)

    poster = ""
    backdrop = ""
    bio = ""
    metaLine = ""
    knownFor = ""
    if detail <> invalid then
        bio = safeToStr(detail.biography)
        if detail.profile_path <> invalid and safeToStr(detail.profile_path) <> "" then
            poster = "https://image.tmdb.org/t/p/w500" + safeToStr(detail.profile_path)
        end if
        bits = []
        dept = safeToStr(detail.known_for_department)
        if dept <> "" then
            bits.push(dept)
            knownFor = dept
        end if
        birthday = safeToStr(detail.birthday)
        if birthday <> "" then bits.push("Born " + birthday)
        place = safeToStr(detail.place_of_birth)
        if place <> "" then bits.push(place)
        if detail.deathday <> invalid and safeToStr(detail.deathday) <> "" then
            bits.push("Died " + safeToStr(detail.deathday))
        end if
        metaLine = joinBits(bits, "  ·  ")
    end if
    if person.profile_path <> invalid and poster = "" then
        poster = "https://image.tmdb.org/t/p/w500" + safeToStr(person.profile_path)
    end if

    credits = []
    if creditsJson <> invalid then
        castList = creditsJson.cast
        if castList <> invalid then
            if GetInterface(castList, "ifArray") = invalid then castList = [castList]
            ' Sort-ish by popularity if present
            maxN = castList.count()
            if maxN > 60 then maxN = 60
            for i = 0 to maxN - 1
                c = castList[i]
                if c <> invalid then
                    title = firstString(c, ["title", "name"])
                    mediaType = safeToStr(c.media_type)
                    if mediaType = "tv" then mediaType = "show"
                    if mediaType = "" then mediaType = "movie"
                    path = ""
                    if c.poster_path <> invalid then path = safeToStr(c.poster_path)
                    thumb = ""
                    if path <> "" then thumb = "https://image.tmdb.org/t/p/w342" + path
                    if c.backdrop_path <> invalid and backdrop = "" then
                        backdrop = "https://image.tmdb.org/t/p/w1280" + safeToStr(c.backdrop_path)
                    end if
                    year = Left(safeToStr(c.release_date), 4)
                    if year = "" then year = Left(safeToStr(c.first_air_date), 4)
                    character = safeToStr(c.character)
                    desc = character
                    if year <> "" and desc <> "" then desc = year + " · " + character
                    if year <> "" and desc = "" then desc = year
                    if title <> "" then
                        credits.push({
                            title: title,
                            description: desc,
                            mediaType: mediaType,
                            ratingKey: "",
                            key: "",
                            hdPosterUrl: thumb,
                            hdBackdropUrl: "",
                            year: year,
                            rating: "",
                            contentRating: "",
                            duration: 0,
                            viewOffset: 0
                        })
                    end if
                end if
            end for
        end if
        ' Also include a few crew credits (director/writer) when cast is thin
        if credits.count() < 15 and creditsJson.crew <> invalid then
            crewList = creditsJson.crew
            if GetInterface(crewList, "ifArray") = invalid then crewList = [crewList]
            maxC = crewList.count()
            if maxC > 20 then maxC = 20
            for i = 0 to maxC - 1
                c = crewList[i]
                job = LCase(safeToStr(c.job))
                if job = "director" or job = "writer" or job = "creator" then
                    title = firstString(c, ["title", "name"])
                    if title <> "" then
                        mediaType = safeToStr(c.media_type)
                        if mediaType = "tv" then mediaType = "show"
                        if mediaType = "" then mediaType = "movie"
                        path = ""
                        if c.poster_path <> invalid then path = safeToStr(c.poster_path)
                        thumb = ""
                        if path <> "" then thumb = "https://image.tmdb.org/t/p/w342" + path
                        credits.push({
                            title: title,
                            description: safeToStr(c.job),
                            mediaType: mediaType,
                            ratingKey: "",
                            key: "",
                            hdPosterUrl: thumb,
                            hdBackdropUrl: "",
                            year: Left(safeToStr(c.release_date), 4),
                            rating: "",
                            contentRating: "",
                            duration: 0,
                            viewOffset: 0
                        })
                    end if
                end if
            end for
        end if
    end if

    return { bio: bio, poster: poster, backdrop: backdrop, credits: credits, metaLine: metaLine, knownFor: knownFor }
end function

function joinBits(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function

function httpGetJson(url as String) as Object
    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(url)
    request.SetRequest("GET")
    request.EnableEncodings(true)
    request.RetainBodyOnError(true)
    request.AddHeader("Accept", "application/json")
    if Left(url, 8) = "https://" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if
    if not request.AsyncGetToString() then return invalid
    while true
        msg = wait(15000, port)
        if msg = invalid then
            request.AsyncCancel()
            return invalid
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            body = msg.GetString()
            if code < 200 or code >= 300 then return invalid
            return ParseJson(body)
        end if
    end while
end function

function fetchLiveTv(cfg as Object) as Object
    rows = []
    errors = []

    dvrId = ""
    dvrs = plexGet(cfg, "/livetv/dvrs")
    if dvrs.ok = true then
        dvrId = firstDvrId(dvrs.json)
    else if dvrs.error <> invalid then
        errors.push(dvrs.error)
    end if

    ' On Now from EPG provider hubs when available
    onNow = fetchLiveTvWatchNow(cfg)
    if onNow.count() > 0 then
        rows.push({ title: "On Now", items: onNow })
    end if

    ' All channels from DVR
    if dvrId <> "" then
        channelsResult = plexGet(cfg, "/livetv/dvrs/" + dvrId + "/channels")
        if channelsResult.ok = true then
            channels = mapLiveTvChannels(cfg, channelsResult.json, dvrId)
            if channels.count() > 0 then rows.push({ title: "Channels", items: channels })
        else if channelsResult.error <> invalid then
            errors.push(channelsResult.error)
        end if

        guideResult = plexGet(cfg, "/livetv/dvrs/" + dvrId + "/guide")
        if guideResult.ok = true then
            guideItems = mapLiveTvGuide(cfg, guideResult.json, dvrId)
            if guideItems.count() > 0 then rows.push({ title: "Guide", items: guideItems })
        end if
    end if

    ' Completed DVR recordings
    recordingsResult = plexGet(cfg, "/livetv/recordings")
    if recordingsResult.ok = true then
        recordings = collectMetadata(cfg, recordingsResult.json)
        if recordings.count() > 0 then
            for each rec in recordings
                rec.mediaType = "recording"
            end for
            rows.push({ title: "Recordings", items: recordings })
        end if
    else if recordingsResult.error <> invalid then
        errors.push(recordingsResult.error)
    end if

    if rows.count() = 0 then
        err = "No Live TV / DVR content found"
        if dvrId = "" then err = "No DVR configured on this Plex server"
        if errors.count() > 0 then err = errors[0]
        return { ok: false, error: err }
    end if

    return { ok: true, rows: rows, dvrId: dvrId }
end function

function fetchLiveTvGuide(cfg as Object) as Object
    dvrId = ""
    dvrs = plexGet(cfg, "/livetv/dvrs")
    if dvrs.ok = true then dvrId = firstDvrId(dvrs.json)
    if dvrId = "" then
        err = "No DVR configured on this Plex server"
        if dvrs.ok <> true and dvrs.error <> invalid then err = dvrs.error
        return { ok: false, error: err }
    end if

    ' Build channel list
    channels = []
    channelsResult = plexGet(cfg, "/livetv/dvrs/" + dvrId + "/channels")
    if channelsResult.ok = true then
        channels = mapLiveTvChannels(cfg, channelsResult.json, dvrId)
    end if

    ' Enrich with what's on now from watchnow / guide
    onNow = fetchLiveTvWatchNow(cfg)
    onNowByChannel = {}
    for each air in onNow
        cid = safeToStr(air.channelId)
        if cid <> "" then onNowByChannel[cid] = air
        ' also index by title fragments
    end for

    guideAirings = []
    dt = CreateObject("roDateTime")
    guideResult = plexGet(cfg, "/livetv/dvrs/" + dvrId + "/guide?time=" + safeToStr(dt.AsSeconds()))
    if guideResult.ok <> true then
        guideResult = plexGet(cfg, "/livetv/dvrs/" + dvrId + "/guide")
    end if
    if guideResult.ok = true then
        guideAirings = mapLiveTvGuide(cfg, guideResult.json, dvrId)
    end if

    ' Prefer richer guide airings as primary channel list when channels empty
    if channels.count() = 0 and guideAirings.count() > 0 then
        channels = guideAirings
    else if channels.count() = 0 and onNow.count() > 0 then
        channels = onNow
    end if

    ' Index all guide airings by channel for now + up-next
    airingsByChannel = {}
    for each g in guideAirings
        gid = safeToStr(g.channelId)
        if gid = "" then gid = safeToStr(g.callSign)
        if gid <> "" then
            if not airingsByChannel.DoesExist(gid) then airingsByChannel[gid] = []
            airingsByChannel[gid].push(g)
        end if
    end for
    for each g in onNow
        gid = safeToStr(g.channelId)
        if gid = "" then gid = safeToStr(g.callSign)
        if gid <> "" then
            if not airingsByChannel.DoesExist(gid) then airingsByChannel[gid] = []
            airingsByChannel[gid].push(g)
        end if
    end for

    nowSec = CreateObject("roDateTime").AsSeconds()

    enriched = []
    for each ch in channels
        cid = safeToStr(ch.channelId)
        airList = []
        if cid <> "" and airingsByChannel.DoesExist(cid) then
            airList = airingsByChannel[cid]
        end if
        if airList.count() = 0 and ch.DoesExist("callSign") then
            cs = asStringSafe(ch.callSign)
            if cs <> "" and airingsByChannel.DoesExist(cs) then airList = airingsByChannel[cs]
        end if

        air = invalid
        nextAir = invalid
        if airList.count() > 0 then
            ' Sort by beginsAt ascending so "next" is correct
            for si = 0 to airList.count() - 2
                for sj = si + 1 to airList.count() - 1
                    bi = 0
                    bj = 0
                    if airList[si].DoesExist("beginsAt") then bi = airList[si].beginsAt
                    if airList[sj].DoesExist("beginsAt") then bj = airList[sj].beginsAt
                    if bj > 0 and (bi = 0 or bj < bi) then
                        tmp = airList[si]
                        airList[si] = airList[sj]
                        airList[sj] = tmp
                    end if
                end for
            end for
            ' Pick current airing (now inside window), else first, and next after it
            bestIdx = -1
            for ai = 0 to airList.count() - 1
                a = airList[ai]
                b = 0
                e = 0
                if a.DoesExist("beginsAt") then b = a.beginsAt
                if a.DoesExist("endsAt") then e = a.endsAt
                if b > 0 and e > b and nowSec >= b and nowSec < e then
                    bestIdx = ai
                    exit for
                end if
            end for
            if bestIdx < 0 then bestIdx = 0
            air = airList[bestIdx]
            if bestIdx + 1 < airList.count() then nextAir = airList[bestIdx + 1]
        end if

        programTitle = asStringSafe(ch.title)
        description = asStringSafe(ch.description)
        poster = asStringSafe(ch.hdPosterUrl)
        backdrop = asStringSafe(ch.hdBackdropUrl)
        timeRange = ""
        nextTitle = ""
        callSign = ""
        if ch.DoesExist("callSign") then callSign = asStringSafe(ch.callSign)
        if callSign = "" then
            candidate = asStringSafe(ch.description)
            if Len(candidate) > 0 and Len(candidate) <= 32 and Instr(1, candidate, " · ") = 0 then
                callSign = candidate
            end if
        end if
        if Instr(1, callSign, " · ") > 0 then
            cut = Instr(1, callSign, " · ")
            callSign = Mid(callSign, 1, cut - 1)
        end if
        if Len(callSign) > 32 then callSign = Mid(callSign, 1, 32)

        if air <> invalid then
            if asStringSafe(air.title) <> "" then programTitle = asStringSafe(air.title)
            if asStringSafe(air.description) <> "" then description = asStringSafe(air.description)
            if asStringSafe(air.hdPosterUrl) <> "" then poster = asStringSafe(air.hdPosterUrl)
            if asStringSafe(air.hdBackdropUrl) <> "" then backdrop = asStringSafe(air.hdBackdropUrl)
            if asStringSafe(air.callSign) <> "" and callSign = "" then callSign = asStringSafe(air.callSign)
            if air.DoesExist("timeRange") then timeRange = asStringSafe(air.timeRange)
        end if
        if nextAir <> invalid then
            nextTitle = asStringSafe(nextAir.title)
            if nextTitle = "" then nextTitle = "—"
            if timeRange = "" and nextAir.DoesExist("timeRange") then
                ' keep empty
            end if
            nextStart = ""
            if nextAir.DoesExist("beginsAt") and nextAir.beginsAt > 0 then
                nextStart = formatClock(nextAir.beginsAt)
            end if
            if nextStart <> "" then nextTitle = nextStart + "  " + nextTitle
        end if
        if nextTitle = "" then nextTitle = "—"
        if timeRange = "" then timeRange = ""

        channelNumber = ""
        if ch.DoesExist("channelNumber") then channelNumber = asStringSafe(ch.channelNumber)
        if channelNumber = "" then channelNumber = firstTokenNumber(asStringSafe(ch.title))

        enriched.push({
            title: asStringSafe(ch.title),
            programTitle: programTitle,
            description: description,
            callSign: callSign,
            channelNumber: channelNumber,
            timeRange: timeRange,
            nextTitle: nextTitle,
            mediaType: "livetv",
            ratingKey: asStringSafe(ch.ratingKey),
            key: asStringSafe(ch.key),
            channelId: cid,
            dvrId: dvrId,
            hdPosterUrl: poster,
            hdBackdropUrl: backdrop
        })
    end for

    if enriched.count() = 0 then
        return { ok: false, error: "No Live TV channels found" }
    end if
    return { ok: true, channels: enriched, dvrId: dvrId }
end function

function asStringSafe(value as Dynamic) as String
    return safeToStr(value)
end function

function firstTokenNumber(title as String) as String
    if title = "" then return ""
    out = ""
    for i = 1 to Len(title)
        ch = Mid(title, i, 1)
        if (ch >= "0" and ch <= "9") or ch = "." then
            out = out + ch
        else if out <> "" then
            exit for
        end if
    end for
    return out
end function

function firstDvrId(json as Object) as String
    if json = invalid or json.MediaContainer = invalid then return ""
    list = json.MediaContainer.Dvr
    if list = invalid then list = json.MediaContainer.Directory
    if list = invalid then list = json.MediaContainer.Metadata
    if list = invalid then return ""
    if GetInterface(list, "ifArray") = invalid then list = [list]
    if list.count() = 0 then return ""
    dvr = list[0]
    id = safeToStr(dvr.key)
    if id = "" then id = safeToStr(dvr.ratingKey)
    if id = "" then id = safeToStr(dvr.uuid)
    ' key may be a path like /livetv/dvrs/1
    marker = "/livetv/dvrs/"
    idx = Instr(1, id, marker)
    if idx > 0 then id = Mid(id, idx + Len(marker))
    return id
end function

function fetchLiveTvWatchNow(cfg as Object) as Object
    items = []
    providers = plexGet(cfg, "/media/providers")
    if providers.ok <> true or providers.json = invalid then return items
    container = providers.json.MediaContainer
    if container = invalid then return items
    list = container.MediaProvider
    if list = invalid then list = container.Provider
    if list = invalid then return items
    if GetInterface(list, "ifArray") = invalid then list = [list]

    for each provider in list
        ident = safeToStr(provider.identifier)
        if ident = "" then ident = safeToStr(provider.id)
        lowerIdent = LCase(ident)
        isEpg = (Instr(1, lowerIdent, "epg") > 0) or (Instr(1, lowerIdent, "livetv") > 0)
        if isEpg then
            featurePath = ""
            features = provider.Feature
            if features = invalid then features = provider.Directory
            if features <> invalid then
                if GetInterface(features, "ifArray") = invalid then features = [features]
                for each feat in features
                    key = safeToStr(feat.key)
                    if Instr(1, LCase(key), "watchnow") > 0 then
                        featurePath = key
                        exit for
                    end if
                end for
            end if
            if featurePath = "" then
                featurePath = "/" + ident + "/watchnow/all"
            end if
            if Left(featurePath, 1) <> "/" then featurePath = "/" + featurePath
            nowResult = plexGet(cfg, featurePath)
            if nowResult.ok = true then
                mapped = mapLiveTvGuide(cfg, nowResult.json, "")
                if mapped.count() = 0 then mapped = collectMetadata(cfg, nowResult.json)
                for each it in mapped
                    mt = safeToStr(it.mediaType)
                    if mt = "" or mt = "movie" or mt = "episode" then it.mediaType = "livetv"
                    if safeToStr(it.channelId) = "" and safeToStr(it.key) <> "" then it.channelId = safeToStr(it.key)
                    items.push(it)
                end for
            end if
            if items.count() > 0 then return items
        end if
    end for
    return items
end function

function mapLiveTvChannels(cfg as Object, json as Object, dvrId as String) as Object
    items = []
    if json = invalid or json.MediaContainer = invalid then return items
    list = json.MediaContainer.Channel
    if list = invalid then list = json.MediaContainer.Directory
    if list = invalid then list = json.MediaContainer.Metadata
    if list = invalid then list = json.MediaContainer.Video
    if list = invalid then return items
    if GetInterface(list, "ifArray") = invalid then list = [list]

    for each ch in list
        channelId = firstString(ch, ["channelIdentifier", "channelId", "identifier", "tag", "key", "ratingKey"])
        callSign = firstString(ch, ["callSign", "title", "name", "label"])
        channelNum = firstString(ch, ["channelNumber", "channel", "index", "number"])
        title = callSign
        if channelNum <> "" and callSign <> "" then
            title = channelNum + "  " + callSign
        else if channelNum <> "" then
            title = "Ch " + channelNum
        end if
        if title = "" then title = "Channel"

        thumb = ""
        if ch.thumb <> invalid then thumb = safeToStr(ch.thumb)
        if thumb = "" and ch.art <> invalid then thumb = safeToStr(ch.art)

        ' Prefer channel number / identifier for tune path
        tuneId = channelId
        if channelNum <> "" then tuneId = channelNum
        if tuneId = "" then tuneId = safeToStr(ch.key)

        items.push({
            title: title,
            description: callSign,
            callSign: callSign,
            channelNumber: channelNum,
            mediaType: "livetv",
            ratingKey: safeToStr(ch.ratingKey),
            key: safeToStr(ch.key),
            channelId: tuneId,
            dvrId: dvrId,
            hdPosterUrl: imageUrl(cfg, thumb, 444, 250),
            hdBackdropUrl: imageUrl(cfg, thumb, 1280, 720),
            duration: 0,
            viewOffset: 0,
            year: "",
            rating: "",
            contentRating: ""
        })
    end for
    return items
end function

function mapLiveTvGuide(cfg as Object, json as Object, dvrId as String) as Object
    items = []
    if json = invalid then return items

    ' Guide can be Metadata list or nested GridChannel → Video/Metadata
    container = json.MediaContainer
    if container = invalid then return items

    list = container.Metadata
    if list = invalid then list = container.Video
    if list = invalid then list = container.Directory
    if list = invalid then list = container.Channel
    if list = invalid then list = container.GridChannel
    if list = invalid then return items
    if GetInterface(list, "ifArray") = invalid then list = [list]

    for each entry in list
        ' Nested airings under a channel node
        airings = entry.Video
        if airings = invalid then airings = entry.Metadata
        if airings <> invalid then
            if GetInterface(airings, "ifArray") = invalid then airings = [airings]
            channelNum = firstString(entry, ["channelNumber", "channelIdentifier", "channel", "title"])
            for each air in airings
                items.push(guideAiringToItem(cfg, air, dvrId, channelNum))
            end for
        else
            items.push(guideAiringToItem(cfg, entry, dvrId, ""))
        end if
        if items.count() >= 200 then exit for
    end for
    return items
end function

function guideAiringToItem(cfg as Object, air as Object, dvrId as String, channelHint as String) as Object
    title = firstString(air, ["title", "grandparentTitle", "name"])
    if title = "" then title = "On Now"
    channelId = firstString(air, ["channelIdentifier", "channelId", "channelNumber", "channel"])
    if channelId = "" then channelId = channelHint
    channelLabel = firstString(air, ["channelTitle", "callSign", "channelIdentifier"])
    if channelLabel = "" then channelLabel = channelHint
    summary = firstString(air, ["summary", "description", "tagline"])
    desc = summary

    thumb = ""
    if air.thumb <> invalid then thumb = safeToStr(air.thumb)
    if thumb = "" and air.grandparentThumb <> invalid then thumb = safeToStr(air.grandparentThumb)
    if thumb = "" and air.art <> invalid then thumb = safeToStr(air.art)

    mediaType = safeToStr(air.type)
    if mediaType = "" then mediaType = "livetv"
    if mediaType <> "recording" then mediaType = "livetv"

    beginsAt = 0
    endsAt = 0
    if air.beginsAt <> invalid then beginsAt = air.beginsAt
    if air.endsAt <> invalid then endsAt = air.endsAt
    if beginsAt = 0 and air.beginTime <> invalid then beginsAt = air.beginTime
    if endsAt = 0 and air.endTime <> invalid then endsAt = air.endTime
    ' Some payloads use milliseconds
    if beginsAt > 100000000000 then beginsAt = Int(beginsAt / 1000)
    if endsAt > 100000000000 then endsAt = Int(endsAt / 1000)

    timeLabel = formatTimeRange(beginsAt, endsAt)

    return {
        title: title,
        description: desc,
        callSign: channelLabel,
        channelNumber: firstTokenNumber(channelHint),
        mediaType: mediaType,
        ratingKey: safeToStr(air.ratingKey),
        key: safeToStr(air.key),
        channelId: channelId,
        dvrId: dvrId,
        hdPosterUrl: imageUrl(cfg, thumb, 444, 250),
        hdBackdropUrl: imageUrl(cfg, thumb, 1280, 720),
        duration: 0,
        viewOffset: 0,
        year: "",
        rating: "",
        contentRating: "",
        beginsAt: beginsAt,
        endsAt: endsAt,
        timeRange: timeLabel
    }
end function

function formatTimeRange(beginsAt as Integer, endsAt as Integer) as String
    if beginsAt <= 0 then return ""
    startLabel = formatClock(beginsAt)
    if endsAt > beginsAt then return startLabel + "–" + formatClock(endsAt)
    return startLabel
end function

function formatClock(epochSec as Integer) as String
    if epochSec <= 0 then return ""
    dt = CreateObject("roDateTime")
    dt.FromSeconds(epochSec)
    dt.ToLocalTime()
    h = dt.GetHours()
    mi = dt.GetMinutes()
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    minStr = StrI(mi).Trim()
    if Len(minStr) = 1 then minStr = "0" + minStr
    return StrI(h12).Trim() + ":" + minStr
end function

function tuneLiveChannel(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No channel" }

    dvrId = safeToStr(item.dvrId)
    channelId = safeToStr(item.channelId)
    if channelId = "" then channelId = safeToStr(item.key)
    if channelId = "" then channelId = safeToStr(item.ratingKey)

    if dvrId = "" then
        dvrs = plexGet(cfg, "/livetv/dvrs")
        if dvrs.ok = true then dvrId = firstDvrId(dvrs.json)
    end if
    if dvrId = "" then return { ok: false, error: "No DVR available to tune" }
    if channelId = "" then return { ok: false, error: "Missing channel id" }
    if item.releaseFirst <> invalid then releaseLiveSession(cfg, item.releaseFirst)

    attempt = plexPost(cfg, "/livetv/dvrs/" + dvrId + "/channels/" + requestEncode(channelId) + "/tune", "")
    failure = tuneFailure(attempt)
    if failure = "" then
        live = liveSessionFromTune(cfg, attempt)
        if live <> invalid then return live
        ' A subscription with no grab means no free tuner; don't leave it holding one
        print "[plexflix:livetv] tune "; channelId; " response: "; Left(safeToStr(attempt.body), 600)
        releaseLiveSession(cfg, { subscriptionId: tunedSubscriptionId(attempt.json) })
        failure = "No free tuner — another preview or recording is using it"
    end if
    print "[plexflix:livetv] tune "; channelId; " failed: "; failure
    return { ok: false, error: failure }
end function

function tunedSubscriptionId(json as Dynamic) as String
    if json = invalid or json.MediaContainer = invalid then return ""
    for each subNode in nodeList(json.MediaContainer.MediaSubscription)
        id = subscriptionId(subNode)
        if id <> "" then return id
    end for
    return ""
end function

' The session is the tuned airing's Media uuid (MediaSubscription >
' MediaGrabOperation > Metadata/Video > Media); Plex plays it through the
' universal transcoder at /livetv/sessions/<uuid>
function liveSessionFromTune(cfg as Object, result as Object) as Dynamic
    body = safeToStr(result.body)
    subId = tunedSubscriptionId(result.json)
    mediaUuid = deepFindMediaUuid(result.json, 0)
    if mediaUuid = "" then
        sessionPath = deepFindString(result.json, "/livetv/sessions/", 0)
        if sessionPath <> "" then mediaUuid = extractLiveSessionId(invalid, Mid(sessionPath, Instr(1, sessionPath, "/livetv/sessions/")))
    end if
    if mediaUuid = "" and Instr(1, body, "MediaGrabOperation") > 0 then mediaUuid = scrapeAttr(body, "uuid")
    if mediaUuid = "" then return invalid
    print "[plexflix:livetv] tuned session "; mediaUuid; " subscription "; subId
    transcodeSession = "plexflix-live-" + mediaUuid
    stream = buildStreamUrl(cfg, { key: "/livetv/sessions/" + mediaUuid, session: transcodeSession })
    stream.subscriptionId = subId
    stream.liveSession = mediaUuid
    return stream
end function

' Ends a live preview/watch: stops its transcode and drops the temporary
' "This Episode" subscription so the tuner is freed right away
function releaseLiveSession(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: true }
    session = safeToStr(item.session)
    if session <> "" then stopTranscode(cfg, { session: session })
    subId = safeToStr(item.subscriptionId)
    if subId <> "" then
        print "[plexflix:livetv] release subscription "; subId
        plexCommand(cfg, "/media/subscriptions/" + requestEncode(subId), "DELETE")
    end if
    return { ok: true }
end function

' /tune answers 200 with status -1 and a message when the tuner refuses
function tuneFailure(result as Object) as String
    if result = invalid then return "No response"
    if result.ok <> true then return safeToStr(result.error)
    if result.json <> invalid and result.json.MediaContainer <> invalid then
        mc = result.json.MediaContainer
        if intOrZero(mc.status) < 0 or (intOrZero(mc.size) = 0 and safeToStr(mc.message) <> "") then
            message = safeToStr(mc.message)
            if message = "" then message = "Plex could not tune this channel"
            return message
        end if
    end if
    return ""
end function

function deepFindString(node as Dynamic, marker as String, depth as Integer) as String
    if node = invalid or depth > 10 then return ""
    nodeType = type(node)
    if nodeType = "String" or nodeType = "roString" then
        if Instr(1, node, marker) > 0 then return node
        return ""
    end if
    if GetInterface(node, "ifAssociativeArray") <> invalid then
        for each keyName in node
            found = deepFindString(node[keyName], marker, depth + 1)
            if found <> "" then return found
        end for
    else if GetInterface(node, "ifArray") <> invalid then
        for each child in node
            found = deepFindString(child, marker, depth + 1)
            if found <> "" then return found
        end for
    end if
    return ""
end function

' Pulls name="value" (XML) or "name":"value" (JSON) out of a raw body
function scrapeAttr(body as String, name as String) as String
    for each marker in [name + "=" + Chr(34), Chr(34) + name + Chr(34) + ":" + Chr(34)]
        at = Instr(1, body, marker)
        if at > 0 then
            rest = Mid(body, at + Len(marker))
            closeAt = Instr(1, rest, Chr(34))
            if closeAt > 1 then return Left(rest, closeAt - 1)
        end if
    end for
    return ""
end function

function deepFindMediaUuid(node as Dynamic, depth as Integer) as String
    if node = invalid or depth > 10 then return ""
    if GetInterface(node, "ifAssociativeArray") <> invalid then
        for each media in nodeList(node.Media)
            uuid = safeToStr(media.uuid)
            if uuid <> "" then return uuid
        end for
        for each keyName in node
            child = node[keyName]
            if child <> invalid and (GetInterface(child, "ifAssociativeArray") <> invalid or GetInterface(child, "ifArray") <> invalid) then
                found = deepFindMediaUuid(child, depth + 1)
                if found <> "" then return found
            end if
        end for
    else if GetInterface(node, "ifArray") <> invalid then
        for each child in node
            found = deepFindMediaUuid(child, depth + 1)
            if found <> "" then return found
        end for
    end if
    return ""
end function

function deepFindMetadataKey(node as Dynamic, depth as Integer) as String
    if node = invalid or depth > 10 then return ""
    if GetInterface(node, "ifAssociativeArray") <> invalid then
        for each keyName in ["Metadata", "Video"]
            for each meta in nodeList(node[keyName])
                key = safeToStr(meta.key)
                if Left(key, 1) = "/" then return key
            end for
        end for
        for each keyName in node
            child = node[keyName]
            if child <> invalid and (GetInterface(child, "ifAssociativeArray") <> invalid or GetInterface(child, "ifArray") <> invalid) then
                found = deepFindMetadataKey(child, depth + 1)
                if found <> "" then return found
            end if
        end for
    else if GetInterface(node, "ifArray") <> invalid then
        for each child in node
            found = deepFindMetadataKey(child, depth + 1)
            if found <> "" then return found
        end for
    end if
    return ""
end function

function extractLiveSessionId(json as Object, body as String) as String
    if json <> invalid and json.MediaContainer <> invalid then
        mc = json.MediaContainer
        for each keyName in ["Session", "Metadata", "Video", "Directory"]
            node = invalid
            if keyName = "Session" then node = mc.Session
            if keyName = "Metadata" then node = mc.Metadata
            if keyName = "Video" then node = mc.Video
            if keyName = "Directory" then node = mc.Directory
            if node <> invalid then
                if GetInterface(node, "ifArray") = invalid then node = [node]
                if node.count() > 0 then
                    entry = node[0]
                    id = firstString(entry, ["sessionKey", "session", "ratingKey", "key", "id"])
                    if id <> "" then
                        marker = "/livetv/sessions/"
                        idx = Instr(1, id, marker)
                        if idx > 0 then return Mid(id, idx + Len(marker))
                        ' key might include slash suffixes
                        slash = Instr(1, id, "/")
                        if slash > 0 then id = Left(id, slash - 1)
                        return id
                    end if
                end if
            end if
        end for
        if mc.sessionKey <> invalid then return safeToStr(mc.sessionKey)
    end if

    ' Fallback: scrape session id from raw body
    if body <> invalid and body <> "" then
        marker = "/livetv/sessions/"
        idx = Instr(1, body, marker)
        if idx > 0 then
            rest = Mid(body, idx + Len(marker))
            out = ""
            for i = 1 to Len(rest)
                ch = Mid(rest, i, 1)
                if ch = "/" or ch = """" or ch = "'" or ch = "<" or ch = " " or ch = "&" then exit for
                out = out + ch
            end for
            return out
        end if
    end if
    return ""
end function

' ---------------------------------------------------------------------------
' Live TV grid guide + DVR
'
' The EPG provider (tv.plex.providers.epg.*) serves the real guide: /grid
' returns program Metadata whose Media entries are the individual airings,
' each carrying beginsAt/endsAt and the channel it airs on (channelIdentifier,
' channelVcn, channelCallSign, channelTitle, channelThumb).
' ---------------------------------------------------------------------------

function nodeList(value as Dynamic) as Object
    if value = invalid then return []
    if GetInterface(value, "ifArray") <> invalid then return value
    if GetInterface(value, "ifAssociativeArray") <> invalid then return [value]
    return []
end function

' Val() is single precision, which would round epoch seconds by minutes
function epochOf(value as Dynamic) as Integer
    if value = invalid then return 0
    valueType = type(value)
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" then return value
    if valueType = "LongInteger" or valueType = "roLongInteger" then
        if value > 100000000000& then return Int(value / 1000)
        return value
    end if
    if valueType = "Float" or valueType = "Double" or valueType = "roFloat" or valueType = "roDouble" then
        if value > 100000000000.0 then return Int(value / 1000)
        return Int(value)
    end if
    if valueType = "String" or valueType = "roString" then
        total# = 0
        for i = 1 to Len(value)
            c = Asc(Mid(value, i, 1)) - 48
            if c < 0 or c > 9 then exit for
            total# = total# * 10 + c
        end for
        if total# > 100000000000.0 then total# = total# / 1000
        return Int(total#)
    end if
    return 0
end function

function truthy(value as Dynamic) as Boolean
    if value = invalid then return false
    s = LCase(safeToStr(value))
    return s = "1" or s = "true"
end function

function firstDvrNode(json as Object) as Dynamic
    if json = invalid or json.MediaContainer = invalid then return invalid
    list = json.MediaContainer.Dvr
    if list = invalid then list = json.MediaContainer.Directory
    list = nodeList(list)
    if list.count() = 0 then return invalid
    return list[0]
end function

function epgProviderId(cfg as Object) as String
    providers = plexGet(cfg, "/media/providers")
    if providers.ok <> true or providers.json = invalid or providers.json.MediaContainer = invalid then return ""
    mc = providers.json.MediaContainer
    list = mc.MediaProvider
    if list = invalid then list = mc.Provider
    for each provider in nodeList(list)
        ident = safeToStr(provider.identifier)
        if Instr(1, LCase(ident), "providers.epg") > 0 then return ident
    end for
    return ""
end function

function liveTvContext(cfg as Object) as Object
    ctx = { dvrId: "", epgId: "", enabled: {}, error: "" }
    dvrs = plexGet(cfg, "/livetv/dvrs")
    if dvrs.ok <> true then
        ctx.error = safeToStr(dvrs.error)
        return ctx
    end if
    ctx.dvrId = firstDvrId(dvrs.json)
    dvr = firstDvrNode(dvrs.json)
    if dvr <> invalid then
        ctx.epgId = safeToStr(dvr.epgIdentifier)
        ' ChannelMapping.enabled says which EPG channels (channelKey) the user kept
        for each dev in nodeList(dvr.Device)
            for each mapping in nodeList(dev.ChannelMapping)
                epgKey = safeToStr(mapping.channelKey)
                if epgKey <> "" then
                    if mapping.enabled = invalid or truthy(mapping.enabled) then ctx.enabled[epgKey] = true
                end if
            end for
        end for
    end if
    if ctx.epgId = "" then ctx.epgId = epgProviderId(cfg)
    print "[plexflix:livetv] dvr="; ctx.dvrId; " epg="; ctx.epgId; " enabled="; ctx.enabled.count()
    return ctx
end function

function epgArt(cfg as Object, meta as Object) as String
    for each keyName in ["art", "grandparentArt", "thumb", "grandparentThumb", "parentThumb"]
        value = safeToStr(meta[keyName])
        if value <> "" then return imageUrlWide(cfg, value, 1280)
    end for
    return ""
end function

function airingFrom(cfg as Object, meta as Object, media as Dynamic) as Dynamic
    src = media
    if src = invalid then src = meta
    beginsAt = epochOf(src.beginsAt)
    endsAt = epochOf(src.endsAt)
    if beginsAt = 0 then beginsAt = epochOf(meta.beginsAt)
    if endsAt = 0 then endsAt = epochOf(meta.endsAt)
    if beginsAt <= 0 or endsAt <= beginsAt then return invalid

    channelId = firstString(src, ["channelIdentifier", "channelID"])
    if channelId = "" then channelId = firstString(meta, ["channelIdentifier", "channelID"])
    vcn = firstString(src, ["channelVcn", "channelNumber"])
    if vcn = "" then vcn = firstString(meta, ["channelVcn", "channelNumber"])
    callSign = firstString(src, ["channelCallSign", "channelShortTitle"])
    if callSign = "" then callSign = firstString(meta, ["channelCallSign", "channelShortTitle"])
    channelTitle = firstString(src, ["channelTitle"])
    if channelTitle = "" then channelTitle = firstString(meta, ["channelTitle"])
    channelThumb = firstString(src, ["channelThumb"])
    if channelThumb = "" then channelThumb = firstString(meta, ["channelThumb"])

    channelKey = channelId
    if channelKey = "" and vcn <> "" then channelKey = "vcn:" + vcn
    if channelKey = "" then channelKey = callSign
    if channelKey = "" then channelKey = channelTitle

    kind = safeToStr(meta.type)
    title = safeToStr(meta.title)
    subtitle = ""
    episodeLabel = ""
    if kind = "episode" then
        show = safeToStr(meta.grandparentTitle)
        if show <> "" then
            if title <> "" and LCase(title) <> LCase(show) then subtitle = title
            title = show
        end if
        season = intOrZero(meta.parentIndex)
        episode = intOrZero(meta.index)
        if season > 0 and episode > 0 then
            episodeLabel = "S" + StrI(season).Trim() + " E" + StrI(episode).Trim()
        else if episode > 0 then
            episodeLabel = "E" + StrI(episode).Trim()
        end if
    else if kind = "movie" then
        subtitle = safeToStr(meta.year)
    end if
    if title = "" then title = "Untitled"

    isNew = truthy(src.premiere) or truthy(meta.premiere)

    return {
        channelKey: channelKey,
        channelId: channelId,
        channelVcn: vcn,
        channelCallSign: callSign,
        channelTitle: channelTitle,
        channelThumb: channelThumb,
        title: title,
        subtitle: subtitle,
        episodeLabel: episodeLabel,
        summary: safeToStr(meta.summary),
        year: safeToStr(meta.year),
        contentRating: safeToStr(meta.contentRating),
        kind: kind,
        guid: safeToStr(meta.guid),
        showGuid: safeToStr(meta.grandparentGuid),
        ratingKey: safeToStr(meta.ratingKey),
        key: safeToStr(meta.key),
        art: epgArt(cfg, meta),
        isNew: isNew,
        placeholder: false,
        beginsAt: beginsAt,
        endsAt: endsAt
    }
end function

function gridAirings(cfg as Object, json as Object, startAt as Integer, endAt as Integer) as Object
    out = []
    if json = invalid or json.MediaContainer = invalid then return out
    mc = json.MediaContainer
    list = mc.Metadata
    if list = invalid then list = mc.Video
    for each meta in nodeList(list)
        medias = nodeList(meta.Media)
        if medias.count() = 0 then medias = [invalid]
        for each media in medias
            air = airingFrom(cfg, meta, media)
            if air <> invalid and air.endsAt > startAt and air.beginsAt < endAt then out.push(air)
        end for
    end for
    return out
end function

function channelSortKey(number as String) as Double
    if number = "" then return 999999999.0
    major# = 0
    minor# = 0
    seenDot = false
    minorDigits = 0
    for i = 1 to Len(number)
        c = Mid(number, i, 1)
        if c >= "0" and c <= "9" then
            if seenDot then
                minor# = minor# * 10 + (Asc(c) - 48)
                minorDigits = minorDigits + 1
            else
                major# = major# * 10 + (Asc(c) - 48)
            end if
        else if (c = "." or c = "-") and not seenDot then
            seenDot = true
        else
            exit for
        end if
    end for
    return major# * 10000 + minor#
end function

function sortChannels(channels as Object) as Object
    keyed = []
    for each ch in channels
        keyed.push({ k: channelSortKey(ch.number), c: ch })
    end for
    ' Insertion sort: guides are a few hundred channels at most
    for i = 1 to keyed.count() - 1
        cur = keyed[i]
        j = i - 1
        while j >= 0 and keyed[j].k > cur.k
            keyed[j + 1] = keyed[j]
            j = j - 1
        end while
        keyed[j + 1] = cur
    end for
    out = []
    for each entry in keyed
        out.push(entry.c)
    end for
    return out
end function

function sortAirings(list as Object) as Object
    for i = 1 to list.count() - 1
        cur = list[i]
        j = i - 1
        while j >= 0 and list[j].beginsAt > cur.beginsAt
            list[j + 1] = list[j]
            j = j - 1
        end while
        list[j + 1] = cur
    end for
    out = []
    lastBegin = -1
    for each air in list
        if air.beginsAt <> lastBegin then out.push(air)
        lastBegin = air.beginsAt
    end for
    return out
end function

function fetchLiveTvGrid(cfg as Object, params as Dynamic) as Object
    if params = invalid then params = {}
    dvrId = safeToStr(params.dvrId)
    epgId = safeToStr(params.epgId)
    enabled = params.enabled
    fresh = truthy(params.fresh) or dvrId = ""

    if fresh then
        ctx = liveTvContext(cfg)
        dvrId = ctx.dvrId
        epgId = ctx.epgId
        enabled = ctx.enabled
        if dvrId = "" then
            err = "No DVR configured on this Plex server"
            if ctx.error <> "" then err = ctx.error
            return { ok: false, error: err }
        end if
    end if
    if enabled = invalid then enabled = {}

    nowSec = CreateObject("roDateTime").AsSeconds()
    startAt = epochOf(params.startAt)
    endAt = epochOf(params.endAt)
    if startAt <= 0 then startAt = nowSec - (nowSec mod 1800)
    if endAt <= startAt then endAt = startAt + 4 * 3600

    airings = []
    gridError = ""
    if epgId <> "" then
        base = "/" + epgId + "/grid?sort=beginsAt&X-Plex-Container-Start=0&X-Plex-Container-Size=4000"
        win = "&endsAt%3E=" + safeToStr(startAt) + "&beginsAt%3C=" + safeToStr(endAt)
        for each path in [base + "&type=1%2C4" + win, base + win]
            res = plexGet(cfg, path)
            if res.ok = true then
                airings = gridAirings(cfg, res.json, startAt, endAt)
                if airings.count() > 0 then exit for
            else
                gridError = safeToStr(res.error)
            end if
        end for
    end if
    print "[plexflix:livetv] grid "; epgId; " "; startAt; "-"; endAt; " airings="; airings.count(); " "; gridError

    byKey = {}
    order = []
    for each air in airings
        ck = air.channelKey
        if ck <> "" then
            if not byKey.DoesExist(ck) then
                number = air.channelVcn
                ' /tune takes the EPG channel identifier, not the guide number
                ' or the tuner's own id from ChannelMapping
                tuneId = air.channelId
                if tuneId = "" then tuneId = number
                name = air.channelTitle
                ' channelTitle is usually "2.1 WCBS"; drop the repeated number
                if number <> "" and Left(name, Len(number) + 1) = number + " " then name = Mid(name, Len(number) + 2)
                callSign = air.channelCallSign
                if callSign = "" then callSign = name
                byKey[ck] = {
                    key: ck,
                    number: number,
                    callSign: callSign,
                    name: name,
                    logo: imageUrl(cfg, air.channelThumb, 160, 90),
                    tuneId: tuneId,
                    tuneAlt: air.channelId,
                    programs: []
                }
                order.push(ck)
            end if
            byKey[ck].programs.push(air)
        end if
    end for

    channels = []
    for each ck in order
        ch = byKey[ck]
        ch.programs = sortAirings(ch.programs)
        channels.push(ch)
    end for

    if fresh and enabled.count() > 0 then
        kept = []
        for each ch in channels
            if ch.tuneAlt = "" or enabled.DoesExist(ch.tuneAlt) then kept.push(ch)
        end for
        if kept.count() > 0 then channels = kept
    end if

    source = "grid"
    if fresh then
        ' Tuner channels with no guide data still belong in the guide
        listed = plexGet(cfg, "/livetv/dvrs/" + dvrId + "/channels")
        if listed.ok = true then
            byNumber = {}
            for each ch in channels
                if ch.number <> "" then byNumber[ch.number] = ch
            end for
            for each extra in mapLiveTvChannels(cfg, listed.json, dvrId)
                number = safeToStr(extra.channelNumber)
                if number <> "" and byNumber.DoesExist(number) then
                    existing = byNumber[number]
                    if existing.logo = "" then existing.logo = safeToStr(extra.hdPosterUrl)
                else if number <> "" or safeToStr(extra.callSign) <> "" then
                    channels.push({
                        key: "dvr:" + number + ":" + safeToStr(extra.callSign),
                        number: number,
                        callSign: safeToStr(extra.callSign),
                        name: safeToStr(extra.callSign),
                        logo: safeToStr(extra.hdPosterUrl),
                        tuneId: safeToStr(extra.channelId),
                        tuneAlt: "",
                        programs: []
                    })
                    if number <> "" then byNumber[number] = channels.peek()
                end if
            end for
        end if

        if airings.count() = 0 then
            source = "fallback"
            legacy = fetchLiveTvGuide(cfg)
            if legacy.ok = true and channels.count() = 0 then
                for each old in legacy.channels
                    programs = []
                    if safeToStr(old.programTitle) <> "" and safeToStr(old.programTitle) <> safeToStr(old.title) then
                        programs.push({ title: safeToStr(old.programTitle), subtitle: "", summary: safeToStr(old.description), beginsAt: 0, endsAt: 0, art: safeToStr(old.hdBackdropUrl), guid: "", showGuid: "", episodeLabel: "", isNew: false, kind: "", placeholder: false })
                    end if
                    channels.push({
                        key: "legacy:" + safeToStr(old.channelId),
                        number: safeToStr(old.channelNumber),
                        callSign: safeToStr(old.callSign),
                        name: safeToStr(old.callSign),
                        logo: "",
                        tuneId: safeToStr(old.channelId),
                        tuneAlt: "",
                        programs: programs
                    })
                end for
            end if
        end if
        channels = sortChannels(channels)
    end if

    if fresh and channels.count() = 0 then
        err = "No Live TV channels found"
        if gridError <> "" then err = gridError
        return { ok: false, error: err }
    end if

    return {
        ok: true,
        source: source,
        dvrId: dvrId,
        epgId: epgId,
        enabled: enabled,
        startAt: startAt,
        endAt: endAt,
        channels: channels
    }
end function

' Tuning live TV creates a temporary "This Episode" subscription with a
' rolling grab; it isn't a recording the user asked for
function isLiveTuneSubscription(subNode as Object) as Boolean
    if safeToStr(subNode.channelIdentifier) <> "" then return true
    for each grab in nodeList(subNode.MediaGrabOperation)
        if truthy(grab.rolling) then return true
    end for
    return false
end function

function subscriptionId(subNode as Object) as String
    id = firstString(subNode, ["key", "id", "ratingKey"])
    marker = "/media/subscriptions/"
    idx = Instr(1, id, marker)
    if idx > 0 then id = Mid(id, idx + Len(marker))
    return id
end function

function subscriptionTypeLabel(subType as Integer) as String
    if subType = 1 then return "Movie"
    if subType = 2 then return "Series"
    if subType = 4 then return "Single airing"
    return "Recording"
end function

function grabToUpcoming(cfg as Object, grab as Object, subId as String, subType as Integer) as Dynamic
    metas = nodeList(grab.Metadata)
    if metas.count() = 0 then metas = nodeList(grab.Video)
    if metas.count() = 0 then return invalid
    meta = metas[0]
    medias = nodeList(meta.Media)
    media = invalid
    if medias.count() > 0 then media = medias[0]
    air = airingFrom(cfg, meta, media)
    if air = invalid then
        air = { title: safeToStr(meta.title), subtitle: "", beginsAt: 0, endsAt: 0, channelKey: "", channelVcn: "", channelCallSign: "", guid: safeToStr(meta.guid), showGuid: safeToStr(meta.grandparentGuid), episodeLabel: "", summary: safeToStr(meta.summary), art: epgArt(cfg, meta), isNew: false, kind: "", placeholder: false }
    end if
    id = subId
    if id = "" then id = safeToStr(grab.mediaSubscriptionID)
    air.subscriptionId = id
    air.subscriptionType = subType
    air.status = safeToStr(grab.status)
    air.grabKey = safeToStr(grab.key)
    return air
end function

function fetchDvrSchedule(cfg as Object) as Object
    upcoming = []
    rules = []
    errors = []

    res = plexGet(cfg, "/media/subscriptions?includeGrabs=1&X-Plex-Container-Size=500")
    if res.ok = true and res.json <> invalid and res.json.MediaContainer <> invalid then
        for each subNode in nodeList(res.json.MediaContainer.MediaSubscription)
          if not isLiveTuneSubscription(subNode) then
            id = subscriptionId(subNode)
            subType = intOrZero(subNode.type)
            target = invalid
            for each candidate in [subNode.Directory, subNode.Video, subNode.Metadata]
                found = nodeList(candidate)
                if target = invalid and found.count() > 0 then target = found[0]
            end for
            title = ""
            guid = ""
            art = ""
            summary = ""
            if target <> invalid then
                title = firstString(target, ["grandparentTitle", "title"])
                guid = safeToStr(target.guid)
                art = epgArt(cfg, target)
                summary = safeToStr(target.summary)
            end if
            if title = "" then title = safeToStr(subNode.title)
            grabs = nodeList(subNode.MediaGrabOperation)
            rules.push({
                id: id,
                title: title,
                type: subType,
                typeLabel: subscriptionTypeLabel(subType),
                guid: guid,
                library: safeToStr(subNode.librarySectionTitle),
                airingsType: safeToStr(subNode.airingsType),
                count: grabs.count(),
                art: art,
                summary: summary,
                settings: ruleSettings(subNode)
            })
            logSettings(id, subNode)
            for each grab in grabs
                item = grabToUpcoming(cfg, grab, id, subType)
                if item <> invalid then upcoming.push(item)
            end for
          end if
        end for
    else if res.error <> invalid then
        errors.push(safeToStr(res.error))
    end if

    if upcoming.count() = 0 then
        scheduled = plexGet(cfg, "/media/subscriptions/scheduled")
        if scheduled.ok = true and scheduled.json <> invalid and scheduled.json.MediaContainer <> invalid then
            for each grab in nodeList(scheduled.json.MediaContainer.MediaGrabOperation)
                item = invalid
                if not truthy(grab.rolling) then item = grabToUpcoming(cfg, grab, "", 0)
                if item <> invalid then upcoming.push(item)
            end for
        end if
    end if

    upcoming = sortAirings(upcoming)
    print "[plexflix:dvr] rules="; rules.count(); " upcoming="; upcoming.count()
    if rules.count() = 0 and upcoming.count() = 0 and errors.count() > 0 then
        return { ok: false, error: errors[0] }
    end if
    return { ok: true, upcoming: upcoming, rules: rules }
end function

' Editable prefs on a rule: enum settings ("0:Any|1:HD only") and booleans
function ruleSettings(subNode as Object) as Object
    out = []
    for each setting in nodeList(subNode.Setting)
        prefId = safeToStr(setting.id)
        if prefId <> "" and not truthy(setting.hidden) then
            label = firstString(setting, ["label", "summary"])
            if label = "" then label = prefId
            value = safeToStr(setting.value)
            if value = "" then value = safeToStr(setting.default)
            choices = []
            enumText = safeToStr(setting.enumValues)
            if enumText <> "" then
                for each pair in enumText.Split("|")
                    colon = Instr(1, pair, ":")
                    if colon > 0 then
                        choices.push({ value: Left(pair, colon - 1), label: Mid(pair, colon + 1) })
                    else if pair <> "" then
                        choices.push({ value: pair, label: pair })
                    end if
                end for
            else if LCase(safeToStr(setting.type)) = "bool" then
                if value = "1" or value = "0" then
                    choices = [{ value: "1", label: "Yes" }, { value: "0", label: "No" }]
                else
                    choices = [{ value: "true", label: "Yes" }, { value: "false", label: "No" }]
                end if
            else if LCase(safeToStr(setting.type)) = "int" then
                lowerId = LCase(prefId)
                ' Padding prefs (startOffsetMinutes / endOffsetMinutes) ship without enumValues
                if Instr(1, lowerId, "offset") > 0 or Instr(1, lowerId, "minutes") > 0 then
                    hasCurrent = false
                    for each n in [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60]
                        text = StrI(n).Trim()
                        if text = value then hasCurrent = true
                        choices.push({ value: text, label: text + " min" })
                    end for
                    if not hasCurrent and value <> "" then choices.push({ value: value, label: value + " min" })
                end if
            end if
            if choices.count() > 1 then out.push({ id: prefId, label: label, value: value, choices: choices })
        end if
    end for
    return out
end function

' Rules listed without their prefs: the subscription template for the same
' guid carries the full Setting list (labels, enums, defaults)
function fetchRuleSettings(cfg as Object, item as Object) as Object
    guid = ""
    if item <> invalid then guid = safeToStr(item.guid)
    if guid = "" then return { ok: false, error: "This rule has no editable settings" }
    res = plexGet(cfg, "/media/subscriptions/template?guid=" + requestEncode(guid))
    if res.ok <> true then return res
    if res.json = invalid or res.json.MediaContainer = invalid then return { ok: false, error: "Plex returned no rule settings" }
    wanted = intOrZero(item.type)
    best = invalid
    for each tpl in nodeList(res.json.MediaContainer.SubscriptionTemplate)
        for each subNode in nodeList(tpl.MediaSubscription)
            if best = invalid or intOrZero(subNode.type) = wanted then best = subNode
        end for
    end for
    if best = invalid then return { ok: false, error: "Plex returned no rule settings" }
    settings = ruleSettings(best)
    logSettings(safeToStr(item.subscriptionId) + " (template)", best)
    return { ok: true, settings: settings }
end function

sub logSettings(label as String, subNode as Object)
    ids = []
    for each setting in nodeList(subNode.Setting)
        ids.push(safeToStr(setting.id) + "=" + safeToStr(setting.value) + "[" + safeToStr(setting.type) + "]")
    end for
    text = ""
    for each part in ids
        if text <> "" then text = text + ", "
        text = text + part
    end for
    print "[plexflix:dvr] rule "; label; " settings: "; text
end sub

function updateRecordingRule(cfg as Object, item as Object) as Object
    id = ""
    if item <> invalid then id = safeToStr(item.subscriptionId)
    if id = "" then return { ok: false, error: "No rule to update" }
    query = ""
    if item.prefs <> invalid then
        for each prefId in item.prefs
            if query <> "" then query = query + "&"
            query = query + "prefs%5B" + prefId + "%5D=" + requestEncode(safeToStr(item.prefs[prefId]))
        end for
    end if
    if query = "" then return { ok: true }
    print "[plexflix:dvr] update subscription "; id; " "; query
    return plexCommand(cfg, "/media/subscriptions/" + requestEncode(id) + "?" + query, "PUT")
end function

function recordOptionLabel(subType as Integer, kind as String) as String
    if subType = 1 then return "Record movie"
    if subType = 2 then return "Record series"
    if subType = 4 then
        if kind = "movie" then return "Record this airing"
        return "Record this episode"
    end if
    return "Record"
end function

function bracketEncode(value as String) as String
    out = value.Replace("[", "%5B")
    return out.Replace("]", "%5D")
end function

function fetchRecordOptions(cfg as Object, item as Object) as Object
    guid = ""
    if item <> invalid then guid = safeToStr(item.guid)
    if guid = "" then return { ok: false, error: "This program has no guide id to record" }
    res = plexGet(cfg, "/media/subscriptions/template?guid=" + requestEncode(guid))
    if res.ok <> true then return res
    mc = invalid
    if res.json <> invalid then mc = res.json.MediaContainer
    if mc = invalid then return { ok: false, error: "Plex returned no recording template" }

    kind = safeToStr(item.kind)
    options = []
    for each tpl in nodeList(mc.SubscriptionTemplate)
        for each subNode in nodeList(tpl.MediaSubscription)
            subType = intOrZero(subNode.type)
            prefsMap = {}
            for each setting in nodeList(subNode.Setting)
                prefId = safeToStr(setting.id)
                value = safeToStr(setting.value)
                if value = "" then value = safeToStr(setting.default)
                if prefId <> "" then prefsMap[prefId] = value
            end for
            options.push({
                label: recordOptionLabel(subType, kind),
                type: subType,
                parameters: bracketEncode(safeToStr(subNode.parameters)),
                librarySectionId: safeToStr(subNode.targetLibrarySectionID),
                locationId: safeToStr(subNode.targetSectionLocationID),
                prefsMap: prefsMap,
                settings: ruleSettings(subNode)
            })
        end for
    end for
    if options.count() = 0 then return { ok: false, error: "Plex can't record this program" }

    ' Single airing first, then series: the common choice leads
    sorted = []
    for each wanted in [4, 1, 2]
        for each opt in options
            if opt.type = wanted then sorted.push(opt)
        end for
    end for
    for each opt in options
        if opt.type <> 4 and opt.type <> 1 and opt.type <> 2 then sorted.push(opt)
    end for
    return { ok: true, options: sorted }
end function

function createRecording(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "Nothing to record" }
    query = safeToStr(item.parameters)
    if query <> "" and Left(query, 1) = "&" then query = Mid(query, 2)
    if query <> "" then query = query + "&"
    query = query + "type=" + safeToStr(item.type)
    if safeToStr(item.librarySectionId) <> "" then query = query + "&targetLibrarySectionID=" + safeToStr(item.librarySectionId)
    if safeToStr(item.locationId) <> "" then query = query + "&targetSectionLocationID=" + safeToStr(item.locationId)
    query = query + "&includeGrabs=1"
    prefs = {}
    if item.prefsMap <> invalid then prefs.Append(item.prefsMap)
    if item.overrides <> invalid then prefs.Append(item.overrides)
    for each prefId in prefs
        query = query + "&prefs%5B" + prefId + "%5D=" + requestEncode(safeToStr(prefs[prefId]))
    end for
    print "[plexflix:dvr] create subscription "; query
    return plexPost(cfg, "/media/subscriptions?" + query, "")
end function

function cancelRecording(cfg as Object, item as Object) as Object
    id = ""
    if item <> invalid then id = safeToStr(item.subscriptionId)
    if id = "" then return { ok: false, error: "No recording to cancel" }
    print "[plexflix:dvr] delete subscription "; id
    return plexCommand(cfg, "/media/subscriptions/" + requestEncode(id), "DELETE")
end function

function fetchSportsFeed(cfg as Object) as Object
    feedUrl = ""
    if cfg.sportsFeedUrl <> invalid then feedUrl = cfg.sportsFeedUrl
    if feedUrl = "" then return { ok: false, error: "sportsFeedUrl is empty in PlexConfig.brs" }

    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(feedUrl)
    request.SetRequest("GET")
    request.EnableEncodings(true)
    request.RetainBodyOnError(true)
    request.AddHeader("Accept", "application/json")
    if Left(feedUrl, 8) = "https://" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if

    if not request.AsyncGetToString() then
        return { ok: false, error: "Failed to start sports feed request" }
    end if

    while true
        msg = wait(20000, port)
        if msg = invalid then
            request.AsyncCancel()
            return { ok: false, error: "Timed out loading sports feed" }
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            body = msg.GetString()
            if code < 200 or code >= 300 then
                return { ok: false, error: "Sports feed HTTP " + safeToStr(code) }
            end if
            parsed = ParseJson(body)
            if parsed = invalid then
                return { ok: false, error: "Could not parse sports feed JSON" }
            end if
            return { ok: true, rows: normalizeSportsFeed(parsed) }
        end if
    end while
end function

function normalizeSportsFeed(parsed as Object) as Object
    rows = []
    if parsed = invalid then return rows

    ' Shape A: category map — { "FOOTBALL": [events...], "24/7 Channels": [...] }
    if GetInterface(parsed, "ifAssociativeArray") <> invalid then
        skipKeys = { providerName: true, lastUpdated: true, language: true, scriptDuration: true }
        for each keyName in parsed
            if not skipKeys.DoesExist(keyName) then
                bucket = parsed[keyName]
                if GetInterface(bucket, "ifArray") <> invalid then
                    items = mapSportsEntries(bucket)
                    if items.count() > 0 then
                        rows.push({ title: keyName, items: items })
                    end if
                end if
            end if
        end for
        if rows.count() > 0 then return rows

        ' Shape B: single list under a known key
        list = invalid
        if parsed.games <> invalid then
            list = parsed.games
        else if parsed.events <> invalid then
            list = parsed.events
        else if parsed.streams <> invalid then
            list = parsed.streams
        else if parsed.items <> invalid then
            list = parsed.items
        else if parsed.data <> invalid then
            list = parsed.data
        end if
        if list <> invalid then
            items = mapSportsEntries(list)
            if items.count() > 0 then rows.push({ title: "Live now", items: items })
            return rows
        end if
    end if

    ' Shape C: bare array of events
    if GetInterface(parsed, "ifArray") <> invalid then
        items = mapSportsEntries(parsed)
        if items.count() > 0 then rows.push({ title: "Live now", items: items })
    end if
    return rows
end function

function mapSportsEntries(list as Object) as Object
    items = []
    if list = invalid then return items
    if GetInterface(list, "ifArray") = invalid then list = [list]

    for each entry in list
        if GetInterface(entry, "ifAssociativeArray") <> invalid then
            title = firstString(entry, ["title", "name", "event", "matchup", "label"])
            streamUrl = extractSportsStreamUrl(entry)
            thumb = firstString(entry, ["thumbnail", "logo", "image", "poster", "thumb", "icon"])
            league = firstString(entry, ["league", "sport", "category", "shortDescription"])
            if title = "" then title = "Live event"
            streams = extractSportsStreams(entry)
            if streams.count() = 0 and streamUrl <> "" then
                streams.push({ title: "Stream 1", streamUrl: streamUrl })
            end if
            if streams.count() > 0 then
                primary = streams[0].streamUrl
                primaryFormat = ""
                if streams[0].streamFormat <> invalid then primaryFormat = streams[0].streamFormat
                items.push({
                    title: title,
                    description: league,
                    mediaType: "sport",
                    key: primary,
                    streamUrl: primary,
                    streamFormat: primaryFormat,
                    streams: streams,
                    streamCount: streams.count(),
                    hdPosterUrl: thumb,
                    hdBackdropUrl: thumb,
                    ratingKey: "",
                    duration: 0,
                    viewOffset: 0,
                    year: "",
                    rating: "",
                    contentRating: ""
                })
            end if
        end if
    end for
    return items
end function

function extractSportsStreams(entry as Object) as Object
    streams = []
    if entry.content <> invalid and entry.content.videos <> invalid then
        videos = entry.content.videos
        if GetInterface(videos, "ifArray") = invalid then videos = [videos]
        idx = 1
        for each video in videos
            if video <> invalid then
                url = safeToStr(video.url)
                if url <> "" then
                    label = firstString(video, ["quality", "videoType"])
                    if label = "" then label = "Stream " + safeToStr(idx)
                    streams.push({ title: label, streamUrl: url, streamFormat: feedStreamFormat(video) })
                    idx = idx + 1
                end if
            end if
        end for
    end if
    if streams.count() > 0 then return streams

    direct = firstString(entry, ["url", "stream", "streamUrl", "src", "link", "playbackUrl"])
    if direct <> "" then streams.push({ title: "Stream", streamUrl: direct })

    sig = safeToStr(entry.streamSignature)
    if sig <> "" then
        startAt = 1
        pipeAt = Instr(startAt, sig, "|")
        altIdx = 1
        while startAt <= Len(sig)
            if pipeAt = 0 then
                url = Mid(sig, startAt)
                pipeAt = Len(sig) + 1
            else
                url = Mid(sig, startAt, pipeAt - startAt)
            end if
            url = url.Trim()
            if url <> "" then
                streams.push({ title: "Alt " + safeToStr(altIdx), streamUrl: url })
                altIdx = altIdx + 1
            end if
            startAt = pipeAt + 1
            pipeAt = Instr(startAt, sig, "|")
        end while
    end if
    return streams
end function

' Direct Publisher feeds name the format in videoType. Proxied URLs hide the
' real playlist path (base64 in the path), so the URL alone can't be trusted.
function feedStreamFormat(video as Object) as String
    kind = LCase(firstString(video, ["videoType", "streamFormat", "format"]))
    if kind = "hls" or kind = "m3u8" then return "hls"
    if kind = "dash" or kind = "mpd" then return "dash"
    if kind = "smooth" or kind = "ism" then return "ism"
    if kind = "mp4" or kind = "mov" or kind = "m4v" then return "mp4"
    return ""
end function

function extractSportsStreamUrl(entry as Object) as String
    ' Prefer proxied HLS from content.videos[]
    if entry.content <> invalid and entry.content.videos <> invalid then
        videos = entry.content.videos
        if GetInterface(videos, "ifArray") = invalid then videos = [videos]
        for each video in videos
            if video <> invalid then
                url = safeToStr(video.url)
                if url <> "" then return url
            end if
        end for
    end if

    direct = firstString(entry, ["url", "stream", "streamUrl", "src", "link", "playbackUrl"])
    if direct <> "" then return direct

    ' streamSignature may be pipe-delimited backup URLs
    sig = safeToStr(entry.streamSignature)
    if sig <> "" then
        pipe = Instr(1, sig, "|")
        if pipe > 0 then return Left(sig, pipe - 1)
        return sig
    end if
    return ""
end function

function firstString(obj as Object, keys as Object) as String
    for each keyName in keys
        if obj.DoesExist(keyName) and obj[keyName] <> invalid then
            value = safeToStr(obj[keyName])
            if value <> "" then return value
        end if
    end for
    return ""
end function

function buildStreamUrl(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "Missing media key for playback" }

    path = safeToStr(item.key)
    if path = "" then
        return { ok: false, error: "Missing media key for playback" }
    end if

    mediaIndex = 0
    if item.mediaIndex <> invalid then mediaIndex = intOrZero(item.mediaIndex)

    ' Universal transcoder → HLS, which Roku Video handles reliably
    query = []
    query.push("hasMDE=1")
    query.push("path=" + requestEncode(path))
    query.push("mediaIndex=" + safeToStr(mediaIndex))
    query.push("partIndex=0")
    query.push("protocol=hls")
    query.push("fastSeek=1")
    query.push("directPlay=0")
    query.push("directStream=1")
    query.push("subtitles=auto")
    query.push("subtitleSize=100")
    query.push("audioBoost=100")
    query.push("location=lan")
    query.push("addDebugOverlay=0")
    query.push("autoAdjustQuality=0")
    query.push("X-Plex-Platform=Roku")
    query.push("X-Plex-Client-Identifier=" + requestEncode(cfg.clientId))
    query.push("X-Plex-Product=" + requestEncode(cfg.product))
    query.push("X-Plex-Device=Roku")
    query.push("X-Plex-Token=" + cfg.token)

    ' A named session can be torn down later instead of leaking a transcode.
    ' No offset= here on purpose: the playlist stays full-length so the player
    ' seeks inside it, which keeps Video.position equal to the media position.
    session = safeToStr(item.session)
    if session <> "" then
        query.push("session=" + requestEncode(session))
        query.push("X-Plex-Session-Identifier=" + requestEncode(session))
    end if

    url = cfg.baseUrl + "/video/:/transcode/universal/start.m3u8?" + joinStrings(query, "&")
    return { ok: true, url: url, session: session }
end function

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function