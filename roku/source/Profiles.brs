' Hardcoded PlexFlix profiles (kids / adults). Applied onto GetPlexConfig()
' after the picker so SideNav, Home, and TV can all read cfg.profile.

function GetProfiles() as Object
    return [
        {
            id: "kids",
            title: "Kids",
            accent: "0x2BB0A6",
            pin: "",
            allowSports: false,
            allowPlexLiveTv: false,
            allowDiscover: false,
            libraryMatch: ["kid", "kids", "children", "child", "family", "cartoon", "disney", "nick"],
            cableAllow: [
                "timst-abc", "timst-nbc", "timst-cbs", "timst-fox", "timst-cw",
                "timst-cartoon-network", "timst-boomerang", "timst-cbeebies",
                "timst-disney-channel", "timst-disney-junior", "timst-disney-xd",
                "timst-nickelodeon", "timst-nick-jr", "timst-nicktoons", "timst-teenick",
                "timst-discovery-family", "timst-starz-kids-and-family"
            ]
        },
        {
            id: "adults",
            title: "Adults",
            accent: "0xE50914",
            pin: "1990",
            allowSports: true,
            allowPlexLiveTv: true,
            allowDiscover: true,
            libraryMatch: [],
            cableAllow: []
        }
    ]
end function

function FindProfile(profileId as String) as Dynamic
    for each p in GetProfiles()
        if p.id = profileId then return p
    end for
    return invalid
end function

function ApplyProfileToConfig(cfg as Object, profile as Object) as Object
    if cfg = invalid then cfg = {}
    if profile = invalid then return cfg
    cfg.profile = profile
    cfg.profileId = profile.id
    return cfg
end function

function ProfileIsKids(cfg as Object) as Boolean
    if cfg = invalid or cfg.profile = invalid then return false
    return cfg.profile.id = "kids"
end function

function ProfileAllowsSports(cfg as Object) as Boolean
    if cfg = invalid or cfg.profile = invalid then return true
    if cfg.profile.allowSports = invalid then return true
    return cfg.profile.allowSports = true
end function

function ProfileAllowsPlexLiveTv(cfg as Object) as Boolean
    if cfg = invalid or cfg.profile = invalid then return true
    if cfg.profile.allowPlexLiveTv = invalid then return true
    return cfg.profile.allowPlexLiveTv = true
end function

function ProfileAllowsDiscover(cfg as Object) as Boolean
    if cfg = invalid or cfg.profile = invalid then return true
    if cfg.profile.allowDiscover = invalid then return true
    return cfg.profile.allowDiscover = true
end function

function ProfileAllowsLibraryTitle(cfg as Object, title as String) as Boolean
    if cfg = invalid or cfg.profile = invalid then return true
    matchers = cfg.profile.libraryMatch
    if matchers = invalid or matchers.count() = 0 then return true
    low = LCase(title)
    for each needle in matchers
        if Instr(1, low, LCase(needle)) > 0 then return true
    end for
    return false
end function

function IsKidsLibraryTitle(title as String) as Boolean
    low = LCase(title)
    matchers = ["kid", "kids", "children", "child", "family", "cartoon", "disney", "nick"]
    for each needle in matchers
        if Instr(1, low, needle) > 0 then return true
    end for
    return false
end function

function ProfileAllowsCableChannel(cfg as Object, feedId as String, title as String) as Boolean
    if cfg = invalid or cfg.profile = invalid then return true
    allow = cfg.profile.cableAllow
    if allow = invalid or allow.count() = 0 then return true
    fid = LCase(feedId)
    t = LCase(title)
    for each needle in allow
        n = LCase(needle)
        if n <> "" then
            if fid = n then return true
            if Instr(1, fid, n) > 0 then return true
            if Instr(1, t, n) > 0 then return true
            ' Allow bare network names against titles ("abc", "cartoon network")
            bare = n
            if Left(bare, 6) = "timst-" then bare = Mid(bare, 7)
            bare = bare.Replace("-", " ")
            if bare <> "" and Instr(1, t, bare) > 0 then return true
        end if
    end for
    return false
end function
