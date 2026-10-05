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
    else if action = "children" then
        m.top.response = fetchChildren(cfg, m.top.item)
    else if action = "extras" then
        m.top.response = fetchExtras(cfg, m.top.item)
    else if action = "pinnedSources" then
        m.top.response = fetchPinnedSources(cfg)
    else if action = "sectionBrowse" then
        m.top.response = fetchSectionBrowse(cfg, m.top.item)
    else if action = "resolveEpisodeShow" then
        m.top.response = resolveEpisodeShow(cfg, m.top.item)
    else if action = "personDetail" then
        m.top.response = fetchPersonDetail(cfg, m.top.item)
    else if action = "liveTv" then
        m.top.response = fetchLiveTv(cfg)
    else if action = "tuneLiveChannel" then
        m.top.response = tuneLiveChannel(cfg, m.top.item)
    else if action = "sportsFeed" then
        m.top.response = fetchSportsFeed(cfg)
    else if action = "streamUrl" then
        m.top.response = buildStreamUrl(cfg, m.top.item)
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

function imageUrl(cfg as Object, path as Dynamic, width = 420 as Integer, height = 630 as Integer) as String
    if path = invalid or path = "" then return ""
    pathStr = safeToStr(path)
    if Left(pathStr, 4) = "http" then return pathStr
    return cfg.baseUrl + "/photo/:/transcode?width=" + safeToStr(width) + "&height=" + safeToStr(height) + "&minSize=1&upscale=1&url=" + requestEncode(pathStr) + "&X-Plex-Token=" + cfg.token
end function

function requestEncode(value as String) as String
    transfer = CreateObject("roUrlTransfer")
    return transfer.Escape(value)
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
    if mediaType = "episode" then
        grandparentTitle = safeToStr(meta.grandparentTitle)
        grandparentRatingKey = safeToStr(meta.grandparentRatingKey)
        parentRatingKey = safeToStr(meta.parentRatingKey)
        season = safeToStr(meta.parentIndex)
        episode = safeToStr(meta.index)
        if grandparentTitle <> "" then
            title = grandparentTitle + " — S" + season + "E" + episode + " " + rawTitle
        end if
        if meta.grandparentThumb <> invalid and thumb = "" then thumb = safeToStr(meta.grandparentThumb)
        if meta.grandparentArt <> invalid and art = "" then art = safeToStr(meta.grandparentArt)
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
        hdBackdropUrl: imageUrl(cfg, art, 1920, 1080),
        duration: duration,
        viewOffset: viewOffset,
        leafCount: meta.leafCount,
        childCount: meta.childCount,
        index: indexVal,
        parentIndex: parentIndexVal,
        grandparentRatingKey: grandparentRatingKey,
        parentRatingKey: parentRatingKey,
        grandparentTitle: grandparentTitle
    }
end function

function appendRow(root as Object, title as String, items as Object) as Boolean
    if items = invalid or items.count() = 0 then return false
    row = root.createChild("ContentNode")
    row.title = title
    for each item in items
        child = row.createChild("ContentNode")
        child.title = item.title
        child.description = item.description
        child.hdPosterUrl = item.hdPosterUrl
        child.hdBackdropUrl = item.hdBackdropUrl
        child.addFields({
            year: item.year,
            rating: item.rating,
            contentRating: item.contentRating,
            mediaType: item.mediaType,
            ratingKey: item.ratingKey,
            key: item.key,
            duration: item.duration,
            viewOffset: item.viewOffset,
            leafCount: item.leafCount,
            childCount: item.childCount,
            grandparentRatingKey: item.grandparentRatingKey,
            parentRatingKey: item.parentRatingKey,
            grandparentTitle: item.grandparentTitle,
            index: item.index,
            shortTitle: item.shortTitle,
            parentIndex: item.parentIndex
        })
    end for
    return true
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

    ' Continue Watching / On Deck
    onDeck = plexGet(cfg, "/library/onDeck")
    if onDeck.ok = true then
        addUniqueRow(root, seenTitles, "Continue Watching", collectMetadata(cfg, onDeck.json))
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

    ' Per-library hubs (this is what fills Netflix-like multi-shelf homes)
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

                    sectionHubs = plexGet(cfg, "/hubs/sections/" + key + "?count=" + safeToStr(cfg.rowSize))
                    if sectionHubs.ok = true and sectionHubs.json <> invalid and sectionHubs.json.MediaContainer <> invalid then
                        appendHubRows(root, seenTitles, sectionHubs.json.MediaContainer.Hub, cfg)
                    end if

                    ' Always include a full library shelf as well
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

    if root.getChildCount() = 0 then
        err = "No rows loaded from Plex."
        if onDeck.ok <> true and onDeck.error <> invalid then err = onDeck.error
        if recent.ok <> true and recent.error <> invalid then err = recent.error
        if sections.ok <> true and sections.error <> invalid then err = sections.error
        return { ok: false, error: err }
    end if

    return { ok: true, content: root }
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

function resolvePlayable(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }

    mediaType = ""
    if item.mediaType <> invalid then mediaType = item.mediaType

    if mediaType = "movie" or mediaType = "episode" then
        return { ok: true, item: item }
    end if

    ' Show -> pick on-deck episode, else first episode of first season
    if mediaType = "show" then
        ' Try metadata children (seasons)
        detail = plexGet(cfg, "/library/metadata/" + item.ratingKey + "/allLeaves?sort=index")
        if detail.ok = true then
            episodes = collectMetadata(cfg, detail.json)
            if episodes.count() > 0 then
                ' Prefer partially watched
                for each ep in episodes
                    if ep.viewOffset <> invalid and ep.viewOffset > 0 then
                        return { ok: true, item: ep }
                    end if
                end for
                ' Else first unwatched-ish / first episode
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

function fetchChildren(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }
    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing ratingKey" }

    result = plexGet(cfg, "/library/metadata/" + ratingKey + "/children")
    if result.ok <> true then return result

    items = collectMetadata(cfg, result.json)
    return { ok: true, items: items }
end function

function fetchExtras(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No item" }
    ratingKey = safeToStr(item.ratingKey)
    if ratingKey = "" then return { ok: false, error: "Missing ratingKey" }

    castItems = []
    similarItems = []

    details = plexGet(cfg, "/library/metadata/" + ratingKey)
    if details.ok = true and details.json <> invalid and details.json.MediaContainer <> invalid then
        meta = details.json.MediaContainer.Metadata
        if meta <> invalid then
            if GetInterface(meta, "ifArray") <> invalid then
                if meta.count() > 0 then meta = meta[0]
            end if
            roles = meta.Role
            if roles <> invalid then
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

    return { ok: true, cast: castItems, similar: similarItems, detail: detail }
end function

function sectionIdFromKey(key as String) as String
    if key = "" then return ""
    marker = "/library/sections/"
    idx = Instr(1, key, marker)
    if idx > 0 then return Mid(key, idx + Len(marker))
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

function fetchSectionBrowse(cfg as Object, item as Object) as Object
    if item = invalid then return { ok: false, error: "No library" }
    sectionId = safeToStr(item.sectionId)
    if sectionId = "" then sectionId = sectionIdFromKey(safeToStr(item.key))
    if sectionId = "" then return { ok: false, error: "Missing library section id" }

    root = createObject("roSGNode", "ContentNode")
    seenTitles = {}
    title = safeToStr(item.title)
    if title = "" then title = "Library"

    hubs = plexGet(cfg, "/hubs/sections/" + sectionId + "?count=" + safeToStr(cfg.rowSize))
    if hubs.ok = true and hubs.json <> invalid and hubs.json.MediaContainer <> invalid then
        appendHubRows(root, seenTitles, hubs.json.MediaContainer.Hub, cfg)
    end if

    allItems = plexGet(cfg, "/library/sections/" + sectionId + "/all?sort=addedAt:desc")
    if allItems.ok = true then
        label = title + " · All"
        addUniqueRow(root, seenTitles, label, collectMetadata(cfg, allItems.json))
    end if

    if root.getChildCount() = 0 then
        return { ok: false, error: "No titles found in " + title }
    end if
    return { ok: true, content: root, title: title }
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

    ' Optional TMDB enrichment
    tmdbKey = ""
    if cfg.tmdbApiKey <> invalid then tmdbKey = safeToStr(cfg.tmdbApiKey)
    if tmdbKey <> "" and tmdbKey <> "REPLACE_WITH_TMDB_API_KEY" and name <> "" then
        tmdb = fetchTmdbPerson(tmdbKey, name)
        if tmdb <> invalid then
            if tmdb.bio <> "" then bio = tmdb.bio
            if tmdb.poster <> "" then poster = tmdb.poster
            if tmdb.backdrop <> "" then backdrop = tmdb.backdrop
            if tmdb.credits <> invalid and tmdb.credits.count() > 0 and credits.count() = 0 then
                credits = tmdb.credits
            end if
        end if
    end if

    return {
        ok: true,
        person: {
            title: name,
            description: bio,
            hdPosterUrl: poster,
            hdBackdropUrl: backdrop,
            mediaType: "actor",
            personId: personId
        },
        credits: credits
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
    if detail <> invalid then
        bio = safeToStr(detail.biography)
        if detail.profile_path <> invalid and safeToStr(detail.profile_path) <> "" then
            poster = "https://image.tmdb.org/t/p/w500" + safeToStr(detail.profile_path)
        end if
    end if
    if person.profile_path <> invalid and poster = "" then
        poster = "https://image.tmdb.org/t/p/w500" + safeToStr(person.profile_path)
    end if

    credits = []
    if creditsJson <> invalid then
        castList = creditsJson.cast
        if castList <> invalid then
            if GetInterface(castList, "ifArray") = invalid then castList = [castList]
            maxN = castList.count()
            if maxN > 24 then maxN = 24
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
                    if title <> "" then
                        credits.push({
                            title: title,
                            description: safeToStr(c.character),
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

    return { bio: bio, poster: poster, backdrop: backdrop, credits: credits }
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
            mediaType: "livetv",
            ratingKey: safeToStr(ch.ratingKey),
            key: safeToStr(ch.key),
            channelId: tuneId,
            dvrId: dvrId,
            hdPosterUrl: imageUrl(cfg, thumb, 480, 270),
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
        if items.count() >= 40 then exit for
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
    desc = channelLabel
    if summary <> "" and desc <> "" then
        desc = channelLabel + " · " + summary
    else if summary <> "" then
        desc = summary
    end if

    thumb = ""
    if air.thumb <> invalid then thumb = safeToStr(air.thumb)
    if thumb = "" and air.grandparentThumb <> invalid then thumb = safeToStr(air.grandparentThumb)
    if thumb = "" and air.art <> invalid then thumb = safeToStr(air.art)

    mediaType = safeToStr(air.type)
    if mediaType = "" then mediaType = "livetv"
    ' Airings without a plex library key still tune by channel
    if mediaType <> "recording" then mediaType = "livetv"

    return {
        title: title,
        description: desc,
        mediaType: mediaType,
        ratingKey: safeToStr(air.ratingKey),
        key: safeToStr(air.key),
        channelId: channelId,
        dvrId: dvrId,
        hdPosterUrl: imageUrl(cfg, thumb, 480, 270),
        hdBackdropUrl: imageUrl(cfg, thumb, 1280, 720),
        duration: 0,
        viewOffset: 0,
        year: "",
        rating: "",
        contentRating: ""
    }
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

    path = "/livetv/dvrs/" + dvrId + "/channels/" + requestEncode(channelId) + "/tune"
    result = plexPost(cfg, path, "")
    if result.ok <> true then return result

    sessionId = extractLiveSessionId(result.json, result.body)
    if sessionId = "" then
        return { ok: false, error: "Tuned, but no Live TV session id was returned" }
    end if

    consumerId = safeToStr(cfg.clientId)
    if consumerId = "" then consumerId = "plexflix-roku"
    url = cfg.baseUrl + "/livetv/sessions/" + sessionId + "/" + requestEncode(consumerId) + "/index.m3u8?X-Plex-Token=" + cfg.token
    return { ok: true, url: url, sessionId: sessionId }
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
                items.push({
                    title: title,
                    description: league,
                    mediaType: "sport",
                    key: primary,
                    streamUrl: primary,
                    streams: streams,
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
                    streams.push({ title: label, streamUrl: url })
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
            url = Trim(url)
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

    ' Universal transcoder → HLS, which Roku Video handles reliably
    query = []
    query.push("hasMDE=1")
    query.push("path=" + requestEncode(path))
    query.push("mediaIndex=0")
    query.push("partIndex=0")
    query.push("protocol=hls")
    query.push("fastSeek=1")
    query.push("directPlay=0")
    query.push("directStream=1")
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

    if item.viewOffset <> invalid and item.viewOffset > 0 then
        query.push("offset=" + safeToStr(Int(item.viewOffset)))
    end if

    url = cfg.baseUrl + "/video/:/transcode/universal/start.m3u8?" + joinStrings(query, "&")
    return { ok: true, url: url }
end function

function joinStrings(parts as Object, sep as String) as String
    out = ""
    for i = 0 to parts.count() - 1
        if i > 0 then out = out + sep
        out = out + parts[i]
    end for
    return out
end function