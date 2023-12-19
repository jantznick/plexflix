export const getPlexMostWatchlisted = (plexToken) => {
    return fetch(`https://discover.provider.plex.tv/hubs/sections/home/top_watchlisted?X-Plex-Token=${plexToken}&X-Plex-Language=en`, {
        method: "GET",
        headers: {
            "accept": "application/json, text/plain, */*",
        },
    }).then(response => response.text())
    .then(data => {
        console.log(data)
    });
}

export const getPlexUrls = (genre, plexToken) => {
    `https://discover.provider.plex.tv/library/platforms/disney-plus/genre-popular-drama?X-Plex-Token=zv7Sx92aZ2KnLYze6Z8W`
}

// https://discover.provider.plex.tv/library/platforms/disney-plus/${types}?X-Plex-Token=zv7Sx92aZ2KnLYze6Z8W
// types:
// ['exclusives', 'trend', 'recently-released', 'platform-popular', 'watchlist']

// ~~~~~~~~~~~~~~~~~~~~~~

// https://discover.provider.plex.tv/library/platforms/disney-plus/genre-popular-${genre}?X-Plex-Token=zv7Sx92aZ2KnLYze6Z8W
// genres:
// ['comedy', 'animation', 'family', 'action', 'adventure', 'crime', 'documentary', 'drama', 'fantasy', romance', 'thriller']
// probably any plex genre
