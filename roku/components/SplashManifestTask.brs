sub init()
    m.top.functionName = "exec"
end sub

sub exec()
    url = m.top.url
    if url = invalid or url = "" then
        m.top.response = { ok: false, error: "empty url" }
        return
    end if

    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.RetainBodyOnError(true)
    xfer.AddHeader("Accept", "application/json")

    body = xfer.GetToString()
    if body = invalid or body = "" then
        m.top.response = { ok: false, error: "empty body" }
        return
    end if

    parsed = ParseJson(body)
    if parsed = invalid then
        m.top.response = { ok: false, error: "bad json" }
        return
    end if

    posters = []
    if GetInterface(parsed, "ifAssociativeArray") <> invalid then
        if parsed.DoesExist("posters") and GetInterface(parsed.posters, "ifArray") <> invalid then
            for each u in parsed.posters
                s = safeStr(u)
                if s <> "" then posters.push(s)
            end for
        else if parsed.DoesExist("rows") and GetInterface(parsed.rows, "ifArray") <> invalid then
            for each row in parsed.rows
                if GetInterface(row, "ifArray") <> invalid then
                    for each u in row
                        s = safeStr(u)
                        if s <> "" then posters.push(s)
                    end for
                end if
            end for
        end if
    else if GetInterface(parsed, "ifArray") <> invalid then
        for each u in parsed
            s = safeStr(u)
            if s <> "" then posters.push(s)
        end for
    end if

    if posters.count() = 0 then
        m.top.response = { ok: false, error: "no posters" }
        return
    end if

    m.top.response = { ok: true, posters: posters }
end sub

function safeStr(value as Dynamic) as String
    if value = invalid then return ""
    t = type(value)
    if t = "String" or t = "roString" then return value
    return ""
end function
