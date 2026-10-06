sub init()
    m.top.functionName = "exec"
end sub

sub exec()
    cfg = m.top.config
    item = m.top.item
    if item = invalid then item = {}
    action = m.top.action

    if action = "create" then
        m.top.response = multiviewRequest(cfg, "POST", "/sessions", FormatJson({ streams: item.streams, layout: item.layout }))
    else if action = "status" then
        m.top.response = multiviewRequest(cfg, "GET", "/sessions/" + item.id, "")
    else if action = "update" then
        body = {}
        if item.layout <> invalid then body.layout = item.layout
        if item.order <> invalid then body.order = item.order
        m.top.response = multiviewRequest(cfg, "PUT", "/sessions/" + item.id, FormatJson(body))
    else if action = "delete" then
        m.top.response = multiviewRequest(cfg, "DELETE", "/sessions/" + item.id, "")
    else
        m.top.response = { ok: false, error: "Unknown multiview action: " + action }
    end if
end sub

function multiviewBase(cfg as Object) as String
    if cfg = invalid or cfg.multiviewUrl = invalid then return ""
    base = cfg.multiviewUrl
    while Right(base, 1) = "/"
        base = Left(base, Len(base) - 1)
    end while
    return base
end function

function multiviewRequest(cfg as Object, method as String, path as String, body as String) as Object
    base = multiviewBase(cfg)
    if base = "" then return { ok: false, error: "multiviewUrl is empty in PlexConfig.brs" }

    request = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    request.SetMessagePort(port)
    request.SetUrl(base + path)
    request.SetRequest(method)
    request.RetainBodyOnError(true)
    request.AddHeader("Accept", "application/json")
    request.AddHeader("Content-Type", "application/json")
    if cfg.multiviewToken <> invalid and cfg.multiviewToken <> "" then
        request.AddHeader("X-Multiview-Token", cfg.multiviewToken)
    end if
    if Left(base, 8) = "https://" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
        request.InitClientCertificates()
    end if

    if method = "GET" then
        started = request.AsyncGetToString()
    else
        ' PUT and DELETE go out through the POST call too: SetRequest above
        ' decides the verb actually sent
        started = request.AsyncPostFromString(body)
    end if
    if not started then return { ok: false, error: "Could not reach the multiview server" }

    while true
        msg = wait(15000, port)
        if msg = invalid then
            request.AsyncCancel()
            return { ok: false, error: "Multiview server timed out" }
        end if
        if type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            parsed = ParseJson(msg.GetString())
            if code < 200 or code >= 300 then
                err = "Multiview server error " + StrI(code).Trim()
                if code < 0 then err = "Can't reach the multiview server (" + msg.GetFailureReason() + ")"
                if parsed <> invalid and parsed.error <> invalid then err = parsed.error
                return { ok: false, error: err, code: code }
            end if
            if parsed = invalid then parsed = {}
            return { ok: true, session: parsed }
        end if
    end while
end function
