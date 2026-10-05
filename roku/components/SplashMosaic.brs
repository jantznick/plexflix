sub init()
    m.rowsRoot = m.top.findNode("rowsRoot")
    m.spinner = m.top.findNode("spinner")
    m.rowNodes = []
    m.rowOffsets = []
    m.rowSpeeds = []
    m.loopWidths = []
    m.posterW = 140
    m.posterH = 210
    m.gap = 14
    m.rowH = 226
    m.numRows = 6
    m.postersPerRow = 12

    if m.spinner <> invalid then m.spinner.control = "start"

    m.tick = createObject("roSGNode", "Timer")
    m.tick.repeat = true
    m.tick.duration = 0.04
    m.tick.observeField("fire", "onTick")

    buildRows(defaultPosterPool())

    if m.top.active = true then m.tick.control = "start"
    if m.top.manifestUrl <> "" then fetchManifest(m.top.manifestUrl)
end sub

sub onActiveChange()
    if m.top.active = true then
        m.top.visible = true
        if m.spinner <> invalid then m.spinner.control = "start"
        m.tick.control = "start"
    else
        m.tick.control = "stop"
        if m.spinner <> invalid then m.spinner.control = "stop"
        m.top.visible = false
    end if
end sub

sub onManifestUrlChange()
    if m.top.manifestUrl <> "" then fetchManifest(m.top.manifestUrl)
end sub

sub fetchManifest(url as String)
    m.manifestTask = createObject("roSGNode", "SplashManifestTask")
    m.manifestTask.url = url
    m.manifestTask.observeField("response", "onManifestReady")
    m.manifestTask.control = "RUN"
end sub

sub onManifestReady()
    response = m.manifestTask.response
    if response = invalid or response.ok <> true then return
    posters = response.posters
    if posters = invalid or posters.count() < 12 then return
    buildRows(posters)
end sub

sub buildRows(pool as Object)
    if m.rowsRoot = invalid then return
    while m.rowsRoot.getChildCount() > 0
        m.rowsRoot.removeChildIndex(0)
    end while
    m.rowNodes = []
    m.rowOffsets = []
    m.rowSpeeds = []
    m.loopWidths = []

    if pool = invalid or pool.count() = 0 then pool = defaultPosterPool()

    stepX = m.posterW + m.gap
    loopW = m.postersPerRow * stepX

    for r = 0 to m.numRows - 1
        row = createObject("roSGNode", "Group")

        ' Two copies of the strip so we can loop seamlessly
        for copy = 0 to 1
            for i = 0 to m.postersPerRow - 1
                idx = (r * 7 + i * 3) MOD pool.count()
                uri = pool[idx]
                p = createObject("roSGNode", "Poster")
                p.width = m.posterW
                p.height = m.posterH
                p.loadDisplayMode = "scaleToZoom"
                p.loadWidth = 280
                p.loadHeight = 420
                p.opacity = 0.78
                if uri <> invalid and uri <> "" then p.uri = uri
                p.translation = [(copy * m.postersPerRow + i) * stepX, 0]
                row.appendChild(p)
            end for
        end for

        m.rowsRoot.appendChild(row)
        m.rowNodes.push(row)
        m.loopWidths.push(loopW)

        ' Alternate direction; vary speed slightly per row (px per tick)
        if (r MOD 2) = 0 then
            m.rowSpeeds.push(1.2 + (r * 0.15))
            m.rowOffsets.push(0 - (r * 40))
        else
            m.rowSpeeds.push(-(1.0 + (r * 0.12)))
            m.rowOffsets.push(-loopW / 3 - (r * 25))
        end if
        row.translation = [m.rowOffsets[r], r * m.rowH]
    end for
end sub

sub onTick()
    if m.rowNodes = invalid then return
    for r = 0 to m.rowNodes.count() - 1
        row = m.rowNodes[r]
        if row <> invalid then
            loopW = m.loopWidths[r]
            speed = m.rowSpeeds[r]
            x = m.rowOffsets[r] + speed
            if speed > 0 then
                if x >= 0 then x = x - loopW
            else
                if x <= -loopW then x = x + loopW
            end if
            m.rowOffsets[r] = x
            row.translation = [x, r * m.rowH]
        end if
    end for
end sub

function defaultPosterPool() as Object
    ' Public TMDB CDN posters — works immediately before your daily script refreshes the CDN.
    base = "https://image.tmdb.org/t/p/w185"
    return [
        base + "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
        base + "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
        base + "/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg",
        base + "/gEU2QniE6E77NI6lCU6MxlNBvVQ.jpg",
        base + "/6FfCtAuVAW8XRjZ7thZycGcfWKN.jpg",
        base + "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
        base + "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg",
        base + "/aWxwnYDmAEYK4pcbmWPKHz2fq2b.jpg",
        base + "/q719jXXEzOoYaps6babgKnONONX.jpg",
        base + "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        base + "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
        base + "/kXfqcdQKsIvE62jhjESQP8bKnOV.jpg",
        base + "/4m1Au3YkjqsxF8iwQy0fFVSiE5B.jpg",
        base + "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        base + "/or06FN3Dka5tukK1e9sl16pB3iy.jpg",
        base + "/iiZZdoQBEYBv6id8su7ImL0oCbO.jpg",
        base + "/wVYREutTvI2tmxr6ujUDNHFhBTr.jpg",
        base + "/qNBAXBIQlnOThruvEs0unQ3xP4S.jpg",
        base + "/1E5baUexWoep7iHtNpctAgQgkMp.jpg",
        base + "/d5NXSklXo0qyIYkgV94aNCWnjHQ.jpg",
        base + "/rktDFPbfHfUbArZ6OOAdi2YHwUQ.jpg",
        base + "/62HCnUTziyWcpDaBO2i1DX17ljH.jpg",
        base + "/8Vt6mWEReuy4Of61Lnj5Xj704mT.jpg",
        base + "/vZloFAK7NmvMGKE7LkUMWqWlQXn.jpg",
        base + "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
        base + "/sKCr78MXSLixwmZ8DyJLrpMsd15.jpg",
        base + "/tX0oVAsBwHgxOCYgp75TG9HafYY.jpg",
        base + "/8UlWHLMpgZm9bx6QYh0NFoq67TZ.jpg",
        base + "/yF1eOkaYvwpO2XaphJEdLgAhQIH.jpg",
        base + "/iZf0KyrE25z1sgkLHmMl4YhWIIy.jpg",
        base + "/9xjZS2rlVxm8SFx8kPC3aIGCOYQ.jpg",
        base + "/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg",
        base + "/xmbU4JTUm8rsdtn7Y3Fcm30GpeT.jpg",
        base + "/wDWwtvkRRlgTiUr6TyLSMX8FNiA.jpg",
        base + "/39wmItkWng5Q6M47KsAtkcFAvQ6.jpg",
        base + "/hZkgoQYus5vegGaoxOjcdPxZxrI.jpg",
        base + "/1g0dhYtq4irTY1GPXvft6k4YLjm.jpg",
        base + "/sv1xJUazXeYqALzczSZ3O6nkH75.jpg",
        base + "/b0Ej6fnXAP8fK75hlyi2jKqdhHz.jpg",
        base + "/5P8SmJz4dO8dSIsW1cKahQiK8R8.jpg",
        base + "/4q2NNj4S5dG2RLEni9sX5F0b0mN.jpg",
        base + "/cDOFGfX9eD6JX5e0eW5QvL2m4bU.jpg",
        base + "/s1VzVhXlqsevi8repCMKLXgzzRc.jpg",
        base + "/bOGkgRGdhrBYJSLpOFZhB8w7J0n.jpg",
        base + "/fZPSd91yGE9fCcCe6OoQr6xyTmD.jpg",
        base + "/t6HIqrJlfTCM0jA2tNOsR19x6sI.jpg",
        base + "/k9tL7bbFRxvLt7EmSNUVfrg6aA6.jpg",
        base + "/7D2efOwDQyT1MZf8j1z0k0Y7Q0Y.jpg",
        base + "/cxVwx2r9wCAv0r7B6mLd0E0b0nY.jpg",
        base + "/vZloFAK7NmvMGKE7LkUMWqWlQXn.jpg",
        base + "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
        base + "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
        base + "/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg",
        base + "/gEU2QniE6E77NI6lCU6MxlNBvVQ.jpg",
        base + "/6FfCtAuVAW8XRjZ7thZycGcfWKN.jpg",
        base + "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
        base + "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg",
        base + "/aWxwnYDmAEYK4pcbmWPKHz2fq2b.jpg",
        base + "/q719jXXEzOoYaps6babgKnONONX.jpg",
        base + "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        base + "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
        base + "/kXfqcdQKsIvE62jhjESQP8bKnOV.jpg",
        base + "/4m1Au3YkjqsxF8iwQy0fFVSiE5B.jpg",
        base + "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        base + "/or06FN3Dka5tukK1e9sl16pB3iy.jpg",
        base + "/iiZZdoQBEYBv6id8su7ImL0oCbO.jpg",
        base + "/wVYREutTvI2tmxr6ujUDNHFhBTr.jpg",
        base + "/qNBAXBIQlnOThruvEs0unQ3xP4S.jpg",
        base + "/1E5baUexWoep7iHtNpctAgQgkMp.jpg",
        base + "/d5NXSklXo0qyIYkgV94aNCWnjHQ.jpg",
        base + "/rktDFPbfHfUbArZ6OOAdi2YHwUQ.jpg",
        base + "/62HCnUTziyWcpDaBO2i1DX17ljH.jpg"
    ]
end function
