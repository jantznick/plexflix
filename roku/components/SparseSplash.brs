sub init()
    m.posterLayer = m.top.findNode("posterLayer")
    m.spinner = m.top.findNode("spinner")
    PinSpinner(m.spinner)
    m.built = false
    if m.top.active = true then activate()
end sub

sub onActiveChange()
    if m.top.active = true then
        activate()
    else
        deactivate()
    end if
end sub

sub onManifestUrlChange()
    if m.top.active = true and m.top.manifestUrl <> "" then fetchManifest(m.top.manifestUrl)
end sub

sub activate()
    m.top.visible = true
    if m.spinner <> invalid then
        m.spinner.control = "start"
        CenterSpinner(m.spinner, 960)
    end if
    if m.built <> true then buildSparse(defaultPosterPool())
    if m.top.manifestUrl <> "" then fetchManifest(m.top.manifestUrl)
end sub

sub deactivate()
    if m.spinner <> invalid then m.spinner.control = "stop"
    m.top.visible = false
    releasePosters()
    m.built = false
end sub

sub fetchManifest(url as String)
    m.manifestTask = createObject("roSGNode", "SplashManifestTask")
    m.manifestTask.url = url
    m.manifestTask.observeField("response", "onManifestReady")
    m.manifestTask.control = "RUN"
end sub

sub onManifestReady()
    if m.top.active <> true then return
    response = m.manifestTask.response
    if response = invalid or response.ok <> true then return
    posters = response.posters
    if posters = invalid or posters.count() < 8 then return
    buildSparse(posters)
end sub

sub releasePosters()
    if m.posterLayer = invalid then return
    while m.posterLayer.getChildCount() > 0
        m.posterLayer.removeChildIndex(0)
    end while
end sub

sub buildSparse(pool as Object)
    if m.posterLayer = invalid then return
    releasePosters()
    if pool = invalid or pool.count() = 0 then pool = defaultPosterPool()

    ' 12 large posters scattered across the screen (not a grid)
    count = 12
    if pool.count() < count then count = pool.count()
    if count < 1 then return

    sizes = [280, 300, 320, 340, 360]
    placed = []
    guard = 0
    i = 0
    while i < count and guard < 80
        guard = guard + 1
        w = sizes[(Rnd(sizes.count()) - 1)]
        h = Int(w * 1.5)
        x = Rnd(1920 - w) - 1
        y = Rnd(1080 - h) - 1
        if x < 0 then x = 0
        if y < 0 then y = 0
        if not overlapsTooMuch(placed, x, y, w, h) then
            p = m.posterLayer.createChild("Poster")
            p.width = w
            p.height = h
            p.translation = [x, y]
            p.loadDisplayMode = "scaleToZoom"
            p.loadWidth = w
            p.loadHeight = h
            p.opacity = 0.55 + (Rnd(25) - 1) / 100.0
            p.uri = pool[(Rnd(pool.count()) - 1)]
            placed.push({ x: x, y: y, w: w, h: h })
            i = i + 1
        end if
    end while
    m.built = true
end sub

function overlapsTooMuch(placed as Object, x as Integer, y as Integer, w as Integer, h as Integer) as Boolean
    for each r in placed
        ' Allow some overlap, but keep centers apart so the layout feels scattered
        cx1 = x + Int(w / 2)
        cy1 = y + Int(h / 2)
        cx2 = r.x + Int(r.w / 2)
        cy2 = r.y + Int(r.h / 2)
        dx = cx1 - cx2
        dy = cy1 - cy2
        if dx < 0 then dx = -dx
        if dy < 0 then dy = -dy
        if dx < Int((w + r.w) * 0.42) and dy < Int((h + r.h) * 0.42) then return true
    end for
    return false
end function

function defaultPosterPool() as Object
    base = "https://image.tmdb.org/t/p/w342"
    return [
        base + "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
        base + "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
        base + "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        base + "/udDclJoHjfjb8Ekgsd4FDteOkCU.jpg",
        base + "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
        base + "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        base + "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
        base + "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
        base + "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg",
        base + "/q719jXXEzOoYaps6babgKnONONX.jpg",
        base + "/or06FN3Dka5tukK1e9sl16pB3iy.jpg",
        base + "/62HCnUTziyWcpDaBO2i1DX17ljH.jpg",
        base + "/sKCr78MXSLixwmZ8DyJLrpMsd15.jpg",
        base + "/8UlWHLMpgZm9bx6QYh0NFoq67TZ.jpg",
        base + "/9xjZS2rlVxm8SFx8kPC3aIGCOYQ.jpg",
        base + "/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg"
    ]
end function
