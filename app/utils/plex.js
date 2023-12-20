
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
