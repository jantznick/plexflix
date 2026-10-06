' Hardcoded connection settings for local MVP testing.
' Update these values before sideloading to your Roku.
function GetPlexConfig() as Object
    return {
        ' Base URL of your Plex Media Server (LAN IP is typical for Roku)
        baseUrl: "http://192.168.1.50:32400",

        ' Plex auth token: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
        token: "REPLACE_WITH_YOUR_PLEX_TOKEN",

        ' Stable client id for this channel
        clientId: "plexflix-roku-mvp-001",

        product: "PlexFlix",
        version: "0.9.8",

        ' How many items to request per row (home clamps display to 15–30)
        rowSize: 40,

        ' Daily-refreshed splash poster pack (JSON with a "posters" URL array).
        ' Built by roku/scripts/update_splash_posters.py on your home server.
        ' Falls back to hardcoded TMDB CDN posters if unreachable.
        splashManifestUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/splash/posters.json",

        ' Live sports JSON feed (editable). Expected objects with title/name + url/stream fields.
        sportsFeedUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/secretfeedfilename.json",

        ' Optional TMDB key for cast bios / photos / known-for when Plex people data is thin.
        ' https://www.themoviedb.org/settings/api
        tmdbApiKey: "REPLACE_WITH_TMDB_API_KEY",

        ' --- Profiles (local gate; not Plex Home managed users) ---
        ' Adult profile is the full app. Kids only sees libraries listed below.
        adultProfileName: "Nick",
        ' PIN required to open the adult profile. Change this before sideload.
        adultPin: "1234",
        kidsProfileName: "Kids",
        ' Plex library titles (case-insensitive exact or contains match)
        kidsLibraries: ["Kids TV", "Kids Movies", "Kids YouTube"],

        ' Set at runtime by ProfileSelectScreen: "" | "adult" | "kids"
        profileMode: ""
    }
end function

function IsKidsMode(cfg as Object) as Boolean
    if cfg = invalid then return false
    mode = ""
    if cfg.DoesExist("profileMode") then mode = LCase(safeConfigStr(cfg.profileMode))
    return mode = "kids"
end function

function IsAdultMode(cfg as Object) as Boolean
    if cfg = invalid then return false
    mode = ""
    if cfg.DoesExist("profileMode") then mode = LCase(safeConfigStr(cfg.profileMode))
    return mode = "adult"
end function

' True when a Plex library title belongs to the kids allow-list in config.
function IsKidsLibraryTitle(cfg as Object, title as String) as Boolean
    if cfg = invalid or title = "" then return false
    names = invalid
    if cfg.DoesExist("kidsLibraries") then names = cfg.kidsLibraries
    if names = invalid or GetInterface(names, "ifArray") = invalid then return false

    needle = LCase(title.Trim())
    for each name in names
        allow = LCase(safeConfigStr(name).Trim())
        if allow <> "" then
            if needle = allow then return true
            ' Title contains the configured name (e.g. "Kids TV Shows" matches "Kids TV")
            if Instr(1, needle, allow) > 0 then return true
        end if
    end for
    return false
end function

function AdultProfileName(cfg as Object) as String
    if cfg = invalid then return "Nick"
    name = ""
    if cfg.DoesExist("adultProfileName") then name = safeConfigStr(cfg.adultProfileName)
    if name = "" then return "Nick"
    return name
end function

function KidsProfileName(cfg as Object) as String
    if cfg = invalid then return "Kids"
    name = ""
    if cfg.DoesExist("kidsProfileName") then name = safeConfigStr(cfg.kidsProfileName)
    if name = "" then return "Kids"
    return name
end function

function AdultPin(cfg as Object) as String
    if cfg = invalid then return ""
    if cfg.DoesExist("adultPin") then return safeConfigStr(cfg.adultPin)
    return ""
end function

function safeConfigStr(value as Dynamic) as String
    if value = invalid then return ""
    valueType = type(value)
    if valueType = "String" or valueType = "roString" then return value
    if valueType = "Integer" or valueType = "roInt" or valueType = "roInteger" or valueType = "LongInteger" then
        return StrI(value).Trim()
    end if
    return ""
end function
