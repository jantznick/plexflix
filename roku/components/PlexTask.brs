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
    else if action = "streamUrl" then
        m.top.response = buildStreamUrl(cfg, m.top.item)
    else
        m.top.response = { ok: false, error: "Unknown action: " + action }
    end if
end sub

function plexGet(cfg as Object, path as String) as Object
    url = cfg.baseUrl + path
    if path.Instr("?") > 0 then
        url = url + "&X-Plex-Token=" + cfg.token
    else
        url = url + "?X-Plex-Token=" + cfg.token
    end if

    ' Prefer JSON for simpler parsing on device
    if url.Instr("X-Plex-Container-Size") = 0 then
        url = url + "&X-Plex-Container-Size=" + cfg.rowSize.toStr()
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
                return { ok: false, error: "Plex HTTP " + code.toStr() + " for " + path }
            end if
            parsed = ParseJson(body)
            if parsed = invalid then
                return { ok: false, error: "Could not parse Plex JSON for " + path }
            end if
            return { ok: true, json: parsed }
        end if
    end while
end function

function imageUrl(cfg as Object, path as Dynamic, width = 420 as Integer, height = 630 as Integer) as String
    if path = invalid or path = "" then return ""
    pathStr = path.toStr()
    if Left(pathStr, 4) = "http" then return pathStr
    return cfg.baseUrl + "/photo/:/transcode?width=" + width.toStr() + "&height=" + height.toStr() + "&minSize=1&upscale=1&url=" + requestEncode(pathStr) + "&X-Plex-Token=" + cfg.token
end function

function requestEncode(value as String) as String
    transfer = CreateObject("roUrlTransfer")
    return transfer.Escape(value)
end function

function metadataToItem(cfg as Object, meta as Object) as Object
    if meta = invalid then return invalid

    mediaType = ""
    if meta.type <> invalid then mediaType = meta.type

    thumb = ""
    art = ""
    if meta.thumb <> invalid then thumb = meta.thumb
    if meta.art <> invalid then art = meta.art

    ratingKey = ""
    key = ""
    if meta.ratingKey <> invalid then ratingKey = meta.ratingKey.toStr()
    if meta.key <> invalid then key = meta.key.toStr()

    title = ""
    if meta.title <> invalid then title = meta.title.toStr()

    ' Episodes: prefer grandparent/parent context in title
    if mediaType = "episode" then
        showTitle = ""
        if meta.grandparentTitle <> invalid then showTitle = meta.grandparentTitle.toStr()
        season = ""
        episode = ""
        if meta.parentIndex <> invalid then season = meta.parentIndex.toStr()
        if meta.index <> invalid then episode = meta.index.toStr()
        if showTitle <> "" then
            title = showTitle + " — S" + season + "E" + episode + " " + title
        end if
        if meta.grandparentThumb <> invalid and thumb = "" then thumb = meta.grandparentThumb
        if meta.grandparentArt <> invalid and art = "" then art = meta.grandparentArt
    end if

    description = ""
    if meta.summary <> invalid then description = meta.summary.toStr()

    year = ""
    if meta.year <> invalid then year = meta.year.toStr()

    rating = ""
    if meta.audienceRating <> invalid then
        rating = meta.audienceRating.toStr()
    else if meta.rating <> invalid then
        rating = meta.rating.toStr()
    end if

    contentRating = ""
    if meta.contentRating <> invalid then contentRating = meta.contentRating.toStr()

    duration = 0
    if meta.duration <> invalid then duration = meta.duration
    viewOffset = 0
    if meta.viewOffset <> invalid then viewOffset = meta.viewOffset

    return {
        title: title,
        description: description,
        year: year,
        rating: rating,
        contentRating: contentRating,
        mediaType: mediaType,
        ratingKey: ratingKey,
        key: key,
        hdPosterUrl: imageUrl(cfg, thumb, 308, 462),
        hdBackdropUrl: imageUrl(cfg, art, 1920, 1080),
        duration: duration,
        viewOffset: viewOffset,
        leafCount: meta.leafCount,
        childCount: meta.childCount
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
            childCount: item.childCount
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

    ' Continue Watching / On Deck
    onDeck = plexGet(cfg, "/library/onDeck")
    if onDeck.ok = true then
        appendRow(root, "Continue Watching", collectMetadata(cfg, onDeck.json))
    end if

    ' Recently Added
    recent = plexGet(cfg, "/library/recentlyAdded")
    if recent.ok = true then
        appendRow(root, "Recently Added", collectMetadata(cfg, recent.json))
    end if

    ' Home hubs (richer Netflix-like shelves when available)
    hubs = plexGet(cfg, "/hubs/home?count=" + cfg.rowSize.toStr())
    if hubs.ok = true and hubs.json <> invalid and hubs.json.MediaContainer <> invalid then
        hubList = hubs.json.MediaContainer.Hub
        if hubList <> invalid then
            if GetInterface(hubList, "ifArray") = invalid then hubList = [hubList]
            for each hub in hubList
                hubTitle = ""
                if hub.title <> invalid then hubTitle = hub.title.toStr()
                ' Skip duplicates we already added
                if hubTitle = "Continue Watching" or hubTitle = "On Deck" or hubTitle = "Recently Added" then
                    ' already covered
                else if hub.Metadata <> invalid then
                    appendRow(root, hubTitle, collectMetadata(cfg, hub))
                end if
            end for
        end if
    end if

    ' Fallback / extra: movie + show libraries as shelves
    sections = plexGet(cfg, "/library/sections")
    if sections.ok = true and sections.json <> invalid and sections.json.MediaContainer <> invalid then
        dirs = sections.json.MediaContainer.Directory
        if dirs <> invalid then
            if GetInterface(dirs, "ifArray") = invalid then dirs = [dirs]
            for each dir in dirs
                sectionType = ""
                if dir.type <> invalid then sectionType = dir.type.toStr()
                if sectionType = "movie" or sectionType = "show" then
                    key = dir.key.toStr()
                    title = dir.title.toStr()
                    allItems = plexGet(cfg, "/library/sections/" + key + "/all?sort=addedAt:desc")
                    if allItems.ok = true then
                        label = title
                        if sectionType = "movie" then label = title + " · Movies"
                        if sectionType = "show" then label = title + " · TV"
                        appendRow(root, label, collectMetadata(cfg, allItems.json))
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

function buildStreamUrl(cfg as Object, item as Object) as Object
    if item = invalid or item.key = invalid or item.key = "" then
        return { ok: false, error: "Missing media key for playback" }
    end if

    ' Universal transcoder → HLS, which Roku Video handles reliably
    path = item.key.toStr()
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
        query.push("offset=" + Int(item.viewOffset).toStr())
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