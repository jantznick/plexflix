
export const serviceTypes = [{
        title: 'Exclusively on ',
        slug: 'exclusives'
    }, {
        title: 'Trending on ',
        slug: 'trend'
    }, {
        title: 'Recently Released on ',
        slug: 'recently-released'
    }, {
        title: 'Popular now on ',
        slug: 'platform-popular'
    }, {
        title: '',
        slug: 'watchlist'
    }
];

export const services = [{
    name: 'Disney Plus',
    slug: 'disney-plus'
}, {
    name: 'Netflix',
    slug: 'netflix'
}, {
    name: 'Hulu',
    slug: 'hulu'
}, {
    name: 'Amazon Prime Video',
    slug: 'amazon-prime-video'
}, {
    name: 'Apple TV',
    slug: 'apple-tv-plus'
},];


export const getPopularPlexGenresFromService = (plexToken, service) => {
    return fetch(`https://discover.provider.plex.tv/library/platforms/${service}/popular-genres?X-Plex-Token=${plexToken}&X-Plex-Provider-Version=6.4`, {
        method: "GET",
        headers: {
            "accept": "application/json, text/plain, */*",
        },
    }).then(response => response.json())
    .then(data => {
        return data
    });
}

export const getPlexMostWatchlisted = (plexToken) => {
    return fetch(`https://discover.provider.plex.tv/hubs/sections/home/top_watchlisted?X-Plex-Token=${plexToken}&X-Plex-Language=en`, {
        method: "GET",
        headers: {
            "accept": "application/json, text/plain, */*",
        },
    }).then(response => response.json())
    .then(data => {
        return data
    });
}

export const getPlexServiceGenres = (plexToken, service, genre) => {
    return fetch(`https://discover.provider.plex.tv/library/platforms/${service}/genre-popular-${genre}?X-Plex-Token=${plexToken}`, {
        method: "GET",
        headers: {
            "accept": "application/json, text/plain, */*",
        },
    }).then(response => response.json())
    .then(data => {
        return data
    })
}

export const getPlexServiceRankings = (plexToken, service, type) => {
    return fetch(`https://discover.provider.plex.tv/library/platforms/${service}/${type}?X-Plex-Token=${plexToken}`, {
        method: "GET",
        headers: {
            "accept": "application/json, text/plain, */*",
        },
    }).then(response => response.json())
    .then(data => {
        return data
    })
}


// Awards:
// https://discover.provider.plex.tv/library/awards/academy-awards:1929-2023?count=12&includeLibraryPlaylists=1&includeStations=1&includeRecentChannels=1&includeMeta=1&includeExternalMetadata=1&excludeFields=summary&X-Plex-Product=Plex%20Web&X-Plex-Version=4.118.0&X-Plex-Client-Identifier=n6orbtyt3sssd5m6c9o4qjib&X-Plex-Platform=Chrome&X-Plex-Platform-Version=119.0&X-Plex-Features=external-media%2Cindirect-media%2Chub-style-list&X-Plex-Model=bundled&X-Plex-Device=OSX&X-Plex-Device-Screen-Resolution=1609x999%2C3440x1440&X-Plex-Token=zv7Sx92aZ2KnLYze6Z8W&X-Plex-Provider-Version=6.4&X-Plex-Text-Format=plain&X-Plex-Language=en


// based on genre
// https://discover.provider.plex.tv/library/categories/animation?count=12&includeLibraryPlaylists=1&includeStations=1&includeRecentChannels=1&includeMeta=1&includeExternalMetadata=1&excludeFields=summary&X-Plex-Product=Plex%20Web&X-Plex-Version=4.118.0&X-Plex-Client-Identifier=n6orbtyt3sssd5m6c9o4qjib&X-Plex-Platform=Chrome&X-Plex-Platform-Version=119.0&X-Plex-Features=external-media%2Cindirect-media%2Chub-style-list&X-Plex-Model=bundled&X-Plex-Device=OSX&X-Plex-Device-Screen-Resolution=1609x999%2C3440x1440&X-Plex-Token=zv7Sx92aZ2KnLYze6Z8W&X-Plex-Provider-Version=6.4&X-Plex-Text-Format=plain&X-Plex-Language=en
