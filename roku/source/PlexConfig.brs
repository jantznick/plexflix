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
        version: "0.10.32",

        ' How many items to request per row (home clamps display to 15–30)
        rowSize: 40,

        ' Daily-refreshed splash poster pack (JSON with a "posters" URL array).
        ' Built by roku/scripts/update_splash_posters.py on your home server.
        ' Falls back to hardcoded TMDB CDN posters if unreachable.
        splashManifestUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/splash/posters.json",

        ' Live sports JSON feed (editable). Expected objects with title/name + url/stream fields.
        sportsFeedUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/secretfeedfilename.json",

        ' Cable TV listings sidecar (optional). Built by roku/scripts/enrich_cable_epg.py
        ' on a slow cron; merged into Cable TV by channel id. Leave empty to skip.
        cableEpgUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/cable-epg.json",

        ' Multiview compositor on the home server (multiview/ in this repo).
        ' Leave empty to hide multiview from the sports guide.
        ' The Roku calls this itself, so use the server's LAN IP, never localhost:
        ' e.g. "http://192.168.1.20:8095"
        multiviewUrl: "",
        ' Must match MULTIVIEW_TOKEN in its docker-compose.yml when that is set
        multiviewToken: "",

        ' Optional TMDB key for cast bios / photos / known-for when Plex people data is thin.
        ' https://www.themoviedb.org/settings/api
        tmdbApiKey: "REPLACE_WITH_TMDB_API_KEY"
    }
end function
