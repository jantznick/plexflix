// Radarr add movie
var myHeaders = new Headers();
myHeaders.append("Content-Type", "application/json");

var raw = JSON.stringify({
  "tmdbId": 269149,
  "monitored": true,
  "minimumAvailability": "announced",
  "addOptions": {
    "searchForMovie": true
  },
  "rootFolderPath": "/mnt/media/f/movies2",
  "title": "Zootopia",
  "QualityProfileId": 1
});

var requestOptions = {
  method: 'POST',
  headers: myHeaders,
  body: raw,
  redirect: 'follow'
};

fetch("http://${URL}:${PORT}/api/v3/movie?apiKey=${APIKEY}", requestOptions)
  .then(response => response.text())
  .then(result => console.log(result))
  .catch(error => console.log('error', error));

// Sonarr add TV Show
var myHeaders = new Headers();
myHeaders.append("Content-Type", "application/json");

var raw = JSON.stringify({
  "tmdbId": 30873, // Don't think this is needed
  "monitored": true,
  "minimumAvailability": "announced",
  "addOptions": {
    "searchForMovie": true
  },
  "rootFolderPath": "/mnt/media/f/tv",
  "title": "Wallace & Gromit's World of Invention",
  "QualityProfileId": 1,
  "LanguageProfileId": 1, //I'm not sure what this is
  "TvdbId": 203031
});

var requestOptions = {
  method: 'POST',
  headers: myHeaders,
  body: raw,
  redirect: 'follow'
};

fetch("http://${URL}:${PORT}/api/v3/series?apiKey=${APIKEY}", requestOptions)
  .then(response => response.text())
  .then(result => console.log(result))
  .catch(error => console.log('error', error));