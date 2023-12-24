export const searchTmdb = (tmdbToken, searchTerm, searchType) => {
    return fetch(`https://api.themoviedb.org/3/search/${searchType}?query=${searchTerm}&include_adult=false&language=en-US&page=1&api_key=${tmdbToken}`, {
        method: "GET",
        headers: {
            "accept": "application/json, text/plain, */*",
        },
    }).then(response => response.json())
    .then(data => {
        return data
    });
}

export const tmdbExternalIds = (tmdbToken, tmdbId) => {
    return fetch(`https://api.themoviedb.org/3/tv/${tmdbId}/external_ids?api_key=${tmdbToken}`, {
        method: "GET",
        headers: {
            "accept": "application/json, text/plain, */*",
        },
    }).then(response => response.json())
    .then(data => {
        return data
    }); 
}