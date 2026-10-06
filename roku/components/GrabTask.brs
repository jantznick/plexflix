sub init()
    m.top.functionName = "exec"
end sub

sub exec()
    ' Fail-open wrapper: every path must set response; never leave the Task hanging
    response = { ok: false, error: "Grab unavailable", failOpen: true }
    cfg = m.top.config
    item = m.top.item
    if item = invalid then item = {}
    action = m.top.action

    if action = "create" then
        response = grabCreate(cfg, item)
    else if action = "status" then
        response = grabStatus(cfg, item)
    else if action = "lookup" then
        response = grabLookup(cfg, item)
    else
        response = { ok: false, error: "Unknown grab action", failOpen: true }
    end if

    if response = invalid then response = { ok: false, error: "Grab unavailable", failOpen: true }
    if response.DoesExist("failOpen") <> true then response.failOpen = true
    m.top.response = response
end sub

function grabBase(cfg as Object) as String
    if cfg = invalid then return ""
    if cfg.DoesExist("grabUrl") <> true then return ""
    if cfg.grabUrl = invalid then return ""
    base = (cfg.grabUrl + "").Trim()
    if base = "" then return ""
    while Right(base, 1) = "/"
        base = Left(base, Len(base) - 1)
    end while
    if base <> "" and Instr(1, base, "://") = 0 then base = "http://" + base
    return base
end function

function grabCreate(cfg as Object, item as Object) as Object
    body = {
        mediaType: grabMediaType(item),
        title: safeStr(item.title),
        year: safeStr(item.year),
        tmdbId: safeStr(item.tmdbId),
        imdbId: safeStr(item.imdbId),
        tvdbId: safeStr(item.tvdbId),
        guid: safeStr(item.guid)
    }
    if body.mediaType = "episode" then
        body.season = grabInt(item.season, 1)
        body.episode = grabInt(item.episode, 1)
    end if
    return grabRequest(cfg, "POST", "/jobs", FormatJson(body), 8000)
end function

function grabStatus(cfg as Object, item as Object) as Object
    jobId = safeStr(item.id)
    if jobId = "" then return { ok: false, error: "Missing job id", failOpen: true }
    return grabRequest(cfg, "GET", "/jobs/" + jobId, "", 5000)
end function

function grabLookup(cfg as Object, item as Object) as Object
    parts = []
    if safeStr(item.guid) <> "" then parts.push("guid=" + grabEncode(safeStr(item.guid)))
    if safeStr(item.tmdbId) <> "" then parts.push("tmdbId=" + grabEncode(safeStr(item.tmdbId)))
    if safeStr(item.imdbId) <> "" then parts.push("imdbId=" + grabEncode(safeStr(item.imdbId)))
    if parts.count() = 0 then return { ok: false, error: "Nothing to look up", failOpen: true }
    query = parts[0]
    i = 1
    while i < parts.count()
        query = query + "&" + parts[i]
        i = i + 1
    end while
    return grabRequest(cfg, "GET", "/jobs?" + query, "", 5000)
end function

function grabMediaType(item as Object) as String
    mt = LCase(safeStr(item.mediaType))
    if mt = "episode" then return "episode"
    if mt = "show" or mt = "series" or mt = "tv" or mt = "season" then return "episode"
    return "movie"
end function

function grabRequest(cfg as Object, method as String, path as String, body as String, timeoutMs as Integer) as Object
    base = grabBase(cfg)
    if base = "" then
        return { ok: false, error: "Grab server not configured", failOpen: true, notConfigured: true }
    end if

    request = CreateObject("roUrlTransfer")
    if request = invalid then
        return { ok: false, error: "Grab unavailable", failOpen: true }
    end if

    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(base + path)
    request.SetRequest(method)
    request.RetainBodyOnError(true)
    request.AddHeader("Accept", "application/json")
    request.AddHeader("Content-Type", "application/json")
    if cfg.DoesExist("grabToken") and cfg.grabToken <> invalid and cfg.grabToken <> "" then
        request.AddHeader("X-Grab-Token", cfg.grabToken)
    end if
    if Left(base, 8) = "https://" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if

    started = false
    if method = "GET" then
        started = request.AsyncGetToString()
    else
        started = request.AsyncPostFromString(body)
    end if
    if not started then
        return { ok: false, error: "Can't reach grab server", failOpen: true }
    end if

    while true
        msg = wait(timeoutMs, port)
        if msg = invalid then
            request.AsyncCancel()
            return { ok: false, error: "Grab server timed out — try again later", failOpen: true }
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            text = msg.GetString()
            if text = invalid then text = ""
            text = text.Trim()
            parsed = invalid
            if Left(text, 1) = "{" then
                parsed = ParseJson(text)
            end if
            if code < 0 then
                return {
                    ok: false,
                    failOpen: true,
                    error: "Can't reach grab server",
                    code: code
                }
            end if
            if code < 200 or code >= 300 then
                err = "Grab server error"
                if parsed <> invalid and parsed.DoesExist("error") then err = safeStr(parsed.error)
                if err = "" then err = "Grab server error " + StrI(code).Trim()
                return { ok: false, failOpen: true, error: err, code: code, job: parsed }
            end if
            if parsed = invalid then parsed = {}
            return { ok: true, failOpen: true, job: parsed }
        end if
    end while

    return { ok: false, error: "Grab unavailable", failOpen: true }
end function

function safeStr(value as Dynamic) as String
    if value = invalid then return ""
    return (value + "").Trim()
end function

function grabInt(value as Dynamic, fallback as Integer) as Integer
    if value = invalid then return fallback
    if type(value) = "Integer" or type(value) = "LongInteger" or type(value) = "Float" or type(value) = "Double" then
        return Int(value)
    end if
    s = safeStr(value)
    if s = "" then return fallback
    n = s.ToInt()
    if n = 0 and s <> "0" then return fallback
    return n
end function

function grabEncode(value as String) as String
    transfer = CreateObject("roUrlTransfer")
    if transfer = invalid then return value
    return transfer.Escape(value)
end function
