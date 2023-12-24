// Radarr add movie
export const addMovieToRadarr = (radarrServerApiToken, radarrServerIP, radarrPort, tmdbId, title) => {
    return fetch(`http://${radarrServerIP}:${radarrPort}/api/v3/movie?apiKey=${radarrServerApiToken}`, {
        method: "POST",
        headers: {
			"Content-Type": "application/json"
        },
		body: JSON.stringify({
			"tmdbId": tmdbId,
			"monitored": true,
			"minimumAvailability": "announced",
			"addOptions": {
				"searchForMovie": true
			},
			"rootFolderPath": "/mnt/media/f/movies2",
			"title": title,
			"QualityProfileId": 1
		})
    }).then(response => response.json())
    .then(data => {
        return data
    });
}


// Sonarr add TV Show
export const addShowToSonarr = (sonarrServerApiToken, sonarrServerIP, sonarrPort, title, tvdbId) => {
	return fetch(`http://${sonarrServerIP}:${sonarrPort}/api/v3/series?apiKey=${sonarrServerApiToken}`, {
        method: "POST",
        headers: {
			"Content-Type": "application/json"
        },
		body: JSON.stringify({
			// "tmdbId": 30873, // Don't think this is needed
			"monitored": true,
			"minimumAvailability": "announced",
			"addOptions": {
				"searchForMovie": true
			},
			"rootFolderPath": "/mnt/media/f/tv",
			"title": title,
			"QualityProfileId": 1,
			"LanguageProfileId": 1, //I'm not sure what this is
			"TvdbId": tvdbId
		})
    }).then(response => response.json())
    .then(data => {
        return data
    });
}
