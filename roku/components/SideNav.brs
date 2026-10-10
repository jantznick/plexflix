sub init()
    m.navItems = m.top.findNode("navItems")
    m.versionLabel = m.top.findNode("versionLabel")
    m.full = m.top.findNode("full")
    m.mini = m.top.findNode("mini")
    m.miniItems = m.top.findNode("miniItems")
    m.entries = []
    m.libraries = []
    m.index = 0
    m.activeIndex = 0
    m.itemNodes = []
    m.miniNodes = []
    m.rowFocus = "main" ' main | alt | home | search within a dual row
    buildStaticEntries()
    applyExpanded()
    ' Screens finishing a load call setFocus on their own lists; while the
    ' menu is open (it starts open) that would strand it without the remote
    m.top.observeField("focusedChild", "onFocusChainChange")
end sub

sub onFocusChainChange()
    if m.top.expanded = true and m.top.suppressed <> true and not m.top.isInFocusChain() then m.top.setFocus(true)
end sub

sub onConfigReady()
    if m.top.config = invalid then return
    if m.versionLabel <> invalid and m.top.config.version <> invalid then
        m.versionLabel.text = "v" + m.top.config.version
    end if
    loadLibraries()
end sub

function isAdultNav() as Boolean
    return ProfileIsKids(m.top.config) = false
end function

sub buildStaticEntries()
    m.entries = []
    m.entries.push({ id: "homeSearch", kind: "homeSearch", title: "Home" })
    m.entries.push({ id: "livetv", kind: "nav", title: "Live TV" })
    if ProfileAllowsSports(m.top.config) then
        m.entries.push({ id: "sports", kind: "nav", title: "Live Sports" })
    end if
    m.entries.push({ id: "profiles", kind: "nav", title: "Switch Profile" })
    rebuildItems()
end sub

sub loadLibraries()
    m.task = createObject("roSGNode", "PlexTask")
    m.task.config = m.top.config
    m.task.action = "pinnedSources"
    m.task.observeField("response", "onLibrariesLoaded")
    m.task.control = "RUN"
end sub

sub onLibrariesLoaded()
    response = m.task.response
    m.libraries = []
    if response <> invalid and response.ok = true and response.items <> invalid then
        for each lib in response.items
            if ProfileAllowsLibraryTitle(m.top.config, asString(lib.title)) then
                m.libraries.push(lib)
            end if
        end for
    end if

    m.entries = []
    m.entries.push({ id: "homeSearch", kind: "homeSearch", title: "Home" })
    if isAdultNav() then
        appendAdultLibraryEntries()
    else
        for each lib in m.libraries
            m.entries.push({
                id: "lib:" + asString(lib.sectionId),
                kind: "library",
                title: asString(lib.title),
                library: lib
            })
        end for
    end if
    m.entries.push({ id: "livetv", kind: "nav", title: "Live TV" })
    if ProfileAllowsSports(m.top.config) then
        m.entries.push({ id: "sports", kind: "nav", title: "Live Sports" })
    end if
    m.entries.push({ id: "profiles", kind: "nav", title: "Switch Profile" })
    rebuildItems()
    syncActiveIndex()
end sub

function isPrimaryLibraryName(title as String, sectionKind as String) as Boolean
    low = LCase(title)
    if sectionKind = "movie" then
        if low = "movies" or low = "movie" then return true
        if Left(low, 6) = "movies" then return true
        return false
    end if
    if low = "tv shows" or low = "tv" or low = "shows" or low = "television" then return true
    if Left(low, 8) = "tv shows" then return true
    if Left(low, 2) = "tv" and Len(low) <= 10 then return true
    return false
end function

function pickPrimaryLibrary(libs as Object, sectionKind as String) as Dynamic
    if libs = invalid or libs.count() = 0 then return invalid
    for each lib in libs
        if isPrimaryLibraryName(asString(lib.title), sectionKind) then return lib
    end for
    return libs[0]
end function

sub appendAdultLibraryEntries()
    moviesAdult = []
    moviesKids = []
    showsAdult = []
    showsKids = []
    otherLibs = []
    for each lib in m.libraries
        st = asString(lib.sectionType)
        kids = IsKidsLibraryTitle(asString(lib.title))
        if st = "movie" then
            if kids then moviesKids.push(lib) else moviesAdult.push(lib)
        else if st = "show" then
            if kids then showsKids.push(lib) else showsAdult.push(lib)
        else
            otherLibs.push(lib)
        end if
    end for

    moviesPrimary = pickPrimaryLibrary(moviesAdult, "movie")
    moviesKid = invalid
    if moviesKids.count() > 0 then moviesKid = moviesKids[0]
    if moviesPrimary <> invalid or moviesKid <> invalid then
        primary = moviesPrimary
        if primary = invalid then primary = moviesKid
        m.entries.push({
            id: "lib:" + asString(primary.sectionId),
            kind: "librarySplit",
            title: "Movies",
            library: primary,
            altLibrary: moviesKid,
            sectionKind: "movie"
        })
    end if

    showsPrimary = pickPrimaryLibrary(showsAdult, "show")
    showsKid = invalid
    if showsKids.count() > 0 then showsKid = showsKids[0]
    if showsPrimary <> invalid or showsKid <> invalid then
        primary = showsPrimary
        if primary = invalid then primary = showsKid
        m.entries.push({
            id: "lib:" + asString(primary.sectionId),
            kind: "librarySplit",
            title: "TV Shows",
            library: primary,
            altLibrary: showsKid,
            sectionKind: "show"
        })
    end if

    ' Extra adult movie/show libraries (YouTube, etc.) keep their own rows
    if moviesPrimary <> invalid then
        for each lib in moviesAdult
            if asString(lib.sectionId) <> asString(moviesPrimary.sectionId) then
                m.entries.push({
                    id: "lib:" + asString(lib.sectionId),
                    kind: "library",
                    title: asString(lib.title),
                    library: lib
                })
            end if
        end for
    end if
    if showsPrimary <> invalid then
        for each lib in showsAdult
            if asString(lib.sectionId) <> asString(showsPrimary.sectionId) then
                m.entries.push({
                    id: "lib:" + asString(lib.sectionId),
                    kind: "library",
                    title: asString(lib.title),
                    library: lib
                })
            end if
        end for
    end if
    for each lib in otherLibs
        m.entries.push({
            id: "lib:" + asString(lib.sectionId),
            kind: "library",
            title: asString(lib.title),
            library: lib
        })
    end for
end sub

sub rebuildItems()
    while m.navItems.getChildCount() > 0
        m.navItems.removeChildIndex(0)
    end while
    m.itemNodes = []
    m.rowFocus = "main"

    y = 0
    for i = 0 to m.entries.count() - 1
        entry = m.entries[i]
        row = createObject("roSGNode", "Group")
        row.translation = [0, y]

        if entry.kind = "homeSearch" then
            node = buildHomeSearchRow(row)
            m.navItems.appendChild(row)
            m.itemNodes.push(node)
        else if entry.kind = "librarySplit" then
            node = buildLibrarySplitRow(row, entry)
            m.navItems.appendChild(row)
            m.itemNodes.push(node)
        else
            bg = createObject("roSGNode", "Rectangle")
            bg.id = "bg"
            bg.width = 260
            bg.height = 56
            bg.color = "0x1E1E24"
            row.appendChild(bg)

            label = createObject("roSGNode", "Label")
            label.width = 260
            label.height = 56
            label.horizAlign = "center"
            label.vertAlign = "center"
            label.text = entry.title
            label.color = "0xDDDDDD"
            label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 24)
            row.appendChild(label)

            m.navItems.appendChild(row)
            m.itemNodes.push({ kind: "plain", group: row, bg: bg, label: label })
        end if
        y = y + 64
    end for

    rebuildMini()
    if m.index >= m.entries.count() then m.index = 0
    if m.activeIndex >= m.entries.count() then m.activeIndex = 0
    paint()
end sub

function buildHomeSearchRow(row as Object) as Object
    homeBg = row.createChild("Rectangle")
    homeBg.width = 120
    homeBg.height = 56
    homeBg.color = "0x1E1E24"

    homeIcon = row.createChild("Poster")
    homeIcon.width = 36
    homeIcon.height = 36
    homeIcon.translation = [42, 10]
    homeIcon.uri = "pkg:/images/nav_home.png"

    searchBg = row.createChild("Rectangle")
    searchBg.width = 120
    searchBg.height = 56
    searchBg.translation = [140, 0]
    searchBg.color = "0x1E1E24"

    searchIcon = row.createChild("Poster")
    searchIcon.width = 36
    searchIcon.height = 36
    searchIcon.translation = [182, 10]
    searchIcon.uri = "pkg:/images/nav_search.png"

    return {
        kind: "homeSearch",
        group: row,
        homeBg: homeBg,
        searchBg: searchBg,
        homeIcon: homeIcon,
        searchIcon: searchIcon
    }
end function

function buildLibrarySplitRow(row as Object, entry as Object) as Object
    hasAlt = (entry.altLibrary <> invalid)
    mainW = 260
    if hasAlt then mainW = 196

    bg = row.createChild("Rectangle")
    bg.width = mainW
    bg.height = 56
    bg.color = "0x1E1E24"

    label = row.createChild("Label")
    label.width = mainW
    label.height = 56
    label.horizAlign = "center"
    label.vertAlign = "center"
    label.text = entry.title
    label.color = "0xDDDDDD"
    label.font = MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", 24)

    altBg = invalid
    altLabel = invalid
    if hasAlt then
        altBg = row.createChild("Rectangle")
        altBg.width = 56
        altBg.height = 56
        altBg.translation = [204, 0]
        altBg.color = "0x1E1E24"

        altLabel = row.createChild("Label")
        altLabel.width = 56
        altLabel.height = 56
        altLabel.translation = [204, 0]
        altLabel.horizAlign = "center"
        altLabel.vertAlign = "center"
        altLabel.text = "K"
        altLabel.color = "0xDDDDDD"
        altLabel.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 26)
    end if

    return {
        kind: "librarySplit",
        group: row,
        bg: bg,
        label: label,
        altBg: altBg,
        altLabel: altLabel,
        hasAlt: hasAlt
    }
end function

' Same vertical rhythm as the full list, so an icon sits where its label will
' appear when the menu opens
sub rebuildMini()
    while m.miniItems.getChildCount() > 0
        m.miniItems.removeChildIndex(0)
    end while
    m.miniNodes = []

    y = 0
    for each entry in m.entries
        marker = m.miniItems.createChild("Rectangle")
        marker.width = 4
        marker.height = 40
        marker.translation = [0, y + 8]
        marker.color = "0xE50914"
        marker.visible = false

        icon = m.miniItems.createChild("Poster")
        icon.width = 36
        icon.height = 36
        icon.translation = [18, y + 10]
        icon.uri = iconFor(entry)

        m.miniNodes.push({ marker: marker, icon: icon })
        y = y + 64
    end for
end sub

function iconFor(entry as Object) as String
    if entry.id = "home" or entry.kind = "homeSearch" then return "pkg:/images/nav_home.png"
    if entry.id = "search" then return "pkg:/images/nav_search.png"
    if entry.id = "livetv" then return "pkg:/images/nav_live.png"
    if entry.id = "cable" then return "pkg:/images/nav_cable.png"
    if entry.id = "sports" then return "pkg:/images/nav_sports.png"
    if entry.id = "profiles" then return "pkg:/images/nav_profiles.png"
    if entry.kind = "librarySplit" and entry.sectionKind = "show" then return "pkg:/images/nav_tv.png"
    if entry.library <> invalid and asString(entry.library.sectionType) = "show" then
        return "pkg:/images/nav_tv.png"
    end if
    return "pkg:/images/nav_movie.png"
end function

sub paint()
    for i = 0 to m.miniNodes.count() - 1
        node = m.miniNodes[i]
        isActive = (i = m.activeIndex)
        node.marker.visible = isActive
        if isActive then node.icon.blendColor = "0xFFFFFF" else node.icon.blendColor = "0x77777F"
    end for

    for i = 0 to m.itemNodes.count() - 1
        node = m.itemNodes[i]
        focused = (i = m.index)
        if node.kind = "homeSearch" then
            paintHomeSearch(node, focused)
        else if node.kind = "librarySplit" then
            paintLibrarySplit(node, focused)
        else
            if focused then
                node.bg.color = "0xE50914"
                node.label.color = "0xFFFFFF"
            else
                node.bg.color = "0x1E1E24"
                node.label.color = "0xCCCCCC"
            end if
        end if
    end for
end sub

sub paintHomeSearch(node as Object, focused as Boolean)
    homeOn = focused and (m.rowFocus = "home" or m.rowFocus = "main")
    searchOn = focused and m.rowFocus = "search"
    if homeOn then
        node.homeBg.color = "0xE50914"
        node.homeIcon.blendColor = "0xFFFFFF"
    else
        node.homeBg.color = "0x1E1E24"
        if focused then node.homeIcon.blendColor = "0xAAAAAA" else node.homeIcon.blendColor = "0x77777F"
    end if
    if searchOn then
        node.searchBg.color = "0xE50914"
        node.searchIcon.blendColor = "0xFFFFFF"
    else
        node.searchBg.color = "0x1E1E24"
        if focused then node.searchIcon.blendColor = "0xAAAAAA" else node.searchIcon.blendColor = "0x77777F"
    end if
end sub

sub paintLibrarySplit(node as Object, focused as Boolean)
    mainOn = focused and m.rowFocus <> "alt"
    altOn = focused and m.rowFocus = "alt" and node.hasAlt = true
    if mainOn then
        node.bg.color = "0xE50914"
        node.label.color = "0xFFFFFF"
    else
        node.bg.color = "0x1E1E24"
        node.label.color = "0xCCCCCC"
    end if
    if node.hasAlt = true then
        if altOn then
            node.altBg.color = "0xE50914"
            node.altLabel.color = "0xFFFFFF"
        else
            node.altBg.color = "0x1E1E24"
            node.altLabel.color = "0xCCCCCC"
        end if
    end if
end sub

sub onExpandedChange()
    applyExpanded()
end sub

sub applyExpanded()
    m.top.translation = [0, 0]
    if m.top.suppressed = true then
        m.top.visible = false
        return
    end if
    m.top.visible = true
    if m.top.expanded = true then
        m.full.visible = true
        m.mini.visible = false
        m.top.setFocus(true)
    else
        m.full.visible = false
        m.mini.visible = (m.top.railVisible = true)
        ' Reopening should start on the section you are in, not wherever the
        ' cursor was left when the menu was dismissed without a choice
        m.index = m.activeIndex
        m.rowFocus = "main"
    end if
    paint()
end sub

sub onActiveChange()
    syncActiveIndex()
end sub

sub syncActiveIndex()
    active = m.top.active
    if active = invalid or active = "" then return
    for i = 0 to m.entries.count() - 1
        entry = m.entries[i]
        if entry.id = active then
            m.index = i
            m.activeIndex = i
            m.rowFocus = "main"
            paint()
            return
        end if
        if entry.kind = "homeSearch" and (active = "home" or active = "search") then
            m.index = i
            m.activeIndex = i
            if active = "search" then m.rowFocus = "search" else m.rowFocus = "home"
            paint()
            return
        end if
        if entry.kind = "librarySplit" and entry.altLibrary <> invalid then
            if active = "lib:" + asString(entry.altLibrary.sectionId) then
                m.index = i
                m.activeIndex = i
                m.rowFocus = "alt"
                paint()
                return
            end if
        end if
    end for
end sub

sub activateCurrent()
    if m.index < 0 or m.index >= m.entries.count() then return
    entry = m.entries[m.index]
    if entry.kind = "homeSearch" then
        if m.rowFocus = "search" then
            m.top.active = "search"
            m.top.selected = "search"
        else
            m.top.active = "home"
            m.top.selected = "home"
        end if
        return
    end if
    if entry.kind = "librarySplit" then
        lib = entry.library
        if m.rowFocus = "alt" and entry.altLibrary <> invalid then lib = entry.altLibrary
        if lib = invalid then return
        m.top.active = "lib:" + asString(lib.sectionId)
        m.top.selectedLibrary = lib
        m.top.selected = "library"
        return
    end if
    if entry.kind = "library" then
        m.top.active = entry.id
        m.top.selectedLibrary = entry.library
        m.top.selected = "library"
        return
    end if
    m.top.active = entry.id
    m.top.selected = entry.id
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    entry = invalid
    if m.index >= 0 and m.index < m.entries.count() then entry = m.entries[m.index]

    if key = "up" then
        if m.index > 0 then
            m.index = m.index - 1
            m.rowFocus = defaultRowFocus(m.entries[m.index])
            paint()
        end if
        return true
    else if key = "down" then
        if m.index < m.entries.count() - 1 then
            m.index = m.index + 1
            m.rowFocus = defaultRowFocus(m.entries[m.index])
            paint()
        end if
        return true
    else if key = "left" then
        if entry <> invalid and entry.kind = "homeSearch" and m.rowFocus = "search" then
            m.rowFocus = "home"
            paint()
            return true
        end if
        if entry <> invalid and entry.kind = "librarySplit" and m.rowFocus = "alt" then
            m.rowFocus = "main"
            paint()
            return true
        end if
        return true
    else if key = "right" then
        if entry <> invalid and entry.kind = "homeSearch" and m.rowFocus <> "search" then
            m.rowFocus = "search"
            paint()
            return true
        end if
        if entry <> invalid and entry.kind = "librarySplit" and entry.altLibrary <> invalid and m.rowFocus <> "alt" then
            m.rowFocus = "alt"
            paint()
            return true
        end if
        return false
    else if key = "OK" or key = "play" then
        activateCurrent()
        return true
    else if key = "back" then
        ' MainScene owns Back from the open menu: it leaves the channel
        return false
    end if
    return false
end function

function defaultRowFocus(entry as Object) as String
    if entry = invalid then return "main"
    if entry.kind = "homeSearch" then return "home"
    return "main"
end function

function asString(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    return ""
end function
