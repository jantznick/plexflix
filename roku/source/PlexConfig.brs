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
        version: "0.3.5",

        ' How many items to request per row
        rowSize: 36,

        ' Live sports JSON feed (editable). Expected objects with title/name + url/stream fields.
        sportsFeedUrl: "https://roku-hockey.s3.us-west-004.backblazeb2.com/secretfeedfilename.json"
    }
end function
