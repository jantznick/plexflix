sub init()
    m.rowsRoot = m.top.findNode("rowsRoot")
    m.spinner = m.top.findNode("spinner")
    m.rowNodes = []
    m.rowOffsets = []
    m.rowSpeeds = []
    m.loopWidths = []
    m.posterW = 140
    m.posterH = 210
    m.gap = 16
    m.rowH = 226
    m.numRows = 6
    ' Slot count per strip (includes intentional empties). ~1 in 4 slots left blank.
    m.slotsPerRow = 16

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
    loopW = m.slotsPerRow * stepX
    cursor = 0

    for r = 0 to m.numRows - 1
        row = createObject("roSGNode", "Group")
        ' Phase shifts which slots are empty so gaps don't stack into columns
        phase = (r * 2) MOD 4

        ' Two copies of the strip for seamless looping
        for copy = 0 to 1
            for i = 0 to m.slotsPerRow - 1
                ' Leave every 4th slot empty (spread evenly). User likes some missing.
                if ((i + phase) MOD 4) = 3 then goto next_slot

                uri = pool[cursor MOD pool.count()]
                cursor = cursor + 1

                p = createObject("roSGNode", "Poster")
                p.width = m.posterW
                p.height = m.posterH
                p.loadDisplayMode = "scaleToZoom"
                p.loadWidth = 280
                p.loadHeight = 420
                p.opacity = 0.78
                if uri <> invalid and uri <> "" then p.uri = uri
                p.translation = [(copy * m.slotsPerRow + i) * stepX, 0]
                row.appendChild(p)
                next_slot:
            end for
        end for

        m.rowsRoot.appendChild(row)
        m.rowNodes.push(row)
        m.loopWidths.push(loopW)

        ' Half-tile horizontal stagger between rows + alternate scroll direction
        stagger = Int(stepX / 2)
        if (r MOD 2) = 0 then
            m.rowSpeeds.push(1.15 + (r * 0.12))
            m.rowOffsets.push(0 - (r * 18))
        else
            m.rowSpeeds.push(-(1.0 + (r * 0.1)))
            m.rowOffsets.push(-stagger - (r * 22))
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
    ' Verified-200 TMDB CDN posters only (broken URLs caused the random clumps/voids).
    base = "https://image.tmdb.org/t/p/w185"
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
        base + "/7WsyChQLEftFiDOVTGkv3hFpyyt.jpg",
        base + "/xmbU4JTUm8rsdtn7Y3Fcm30GpeT.jpg",
        base + "/1g0dhYtq4irTY1GPXvft6k4YLjm.jpg",
        base + "/sv1xJUazXeYqALzczSZ3O6nkH75.jpg",
        base + "/b0Ej6fnXAP8fK75hlyi2jKqdhHz.jpg",
        base + "/5KCVkau1HEl7ZzfPsKAPM0sMiKc.jpg",
        base + "/o0lO84GI7qrG6XFvtsPOSV7CTNa.jpg",
        base + "/2CAL2433ZeIihfX1Hb2139CX0pW.jpg",
        base + "/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg",
        base + "/2uNW4WbgBXL25BAbXGLnLqX71Sw.jpg",
        base + "/gKkl37BQuKTanygYQG1pyYgLVgf.jpg",
        base + "/uXDfjJbdP4ijW5hWSBrPrlKpxab.jpg"
    ]
end function
