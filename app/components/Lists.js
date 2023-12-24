import { useContext } from "react";

import { PlexContext } from "./App";
import Button from "./Button";

import { fetchChatGptRecommendations, fetchChatGptMatches } from '../utils/openAi';

const Lists = () => {
    const {
        recommendationsList,
        openAiToken,
        tmdbToken,
        media,
		plexTitles,
        setInterstitial,
		setRecommendationsList,
        setMedia
	} = useContext(PlexContext)

    const submitRecommendationsList = () => {
		const fetchedRecommendations = fetchChatGptRecommendations(openAiToken, recommendationsList);
		fetchedRecommendations.then(({stopReason, jsonRecs}) => {
			if (stopReason === 'stop') {
				const eachPromises = jsonRecs.map((recommendation, i1) => {
					const promises = recommendation.suggested_movies.map(movie => {
						// TODO: Chatgpt needs to add media type to the response so that we can search if it's a movie or a tv show
						return fetch(`https://api.themoviedb.org/3/search/${movie.mediaType}?query=${movie.title}&include_adult=false&language=en-US&page=1&api_key=${tmdbToken}`, {
							method: "GET",
							headers: {
								accept: 'application/json'
							}
						}).then(res => res.json());
					})
					return Promise.all(promises).then(values => {
						const newTitles = []
						values.map((title, i2) => {
							const mediaType = jsonRecs[i1].suggested_movies[i2].mediaType;
							newTitles.push({
								title: title.results[0]?.[mediaType == 'tv' ? 'original_name' : 'original_title'],
								tagline: '',
								year: title.results[0]?.[mediaType == 'tv' ? 'first_air_date' : 'release_date'].substr(0, 4),
								poster_path: `https://image.tmdb.org/t/p/original${title.results[0]?.poster_path}`,
								backdrop_path: `https://image.tmdb.org/t/p/original${title.results[0]?.backdrop_path}`,
								mediaType: mediaType,
								tmdbId: title.results[0]?.id
							})
						})
						return {
							mediaProvidedBy: 'chatGPT',
							title: `${recommendation.category} - Because you liked ${recommendation.given_movies[0]}`,
							rowId: media.length + 1,
							titles: newTitles,
							marginPad: Math.floor(Math.random() * 3) * 65
						}
					})
				})
				Promise.all(eachPromises).then(values => {
					setMedia([
						...media,
						...values
					])
                    setInterstitial(false)
					window.document.getElementsByTagName('body')[0].style.overflowY = '';
				})
			}
		});
    }

	// TODO: verify that there are movies available, and probably a big list
	// TODO: Change the plexTitle array to be all plex titles and data so that it can be used here to get data not go to tmdb
    const submitMatchesList = () => {
		const fetchedRecommendations = fetchChatGptMatches(openAiToken, [recommendationsList, plexTitles]);
		fetchedRecommendations.then(({stopReason, jsonMatches}) => {
			if (stopReason === 'stop') {
				const promises = jsonMatches.suggested_movies.map(movie => {
					return fetch(`https://api.themoviedb.org/3/search/${movie.mediaType}?query=${movie.title}&include_adult=false&language=en-US&page=1&api_key=${tmdbToken}`, {
						method: "GET",
						headers: {
							accept: 'application/json'
						}
					}).then(res => res.json());
				})
				return Promise.all(promises).then(values => {
					const newTitles = []
					values.map((title, i) => {
						const mediaType = jsonMatches.suggested_movies[i].mediaType;
						newTitles.push({
							title: title.results[0]?.[mediaType == 'tv' ? 'original_name' : 'original_title'],
							tagline: '',
							year: title.results[0]?.[mediaType == 'tv' ? 'first_air_date' : 'release_date'].substr(0, 4),
							poster_path: `https://image.tmdb.org/t/p/original${title.results[0]?.poster_path}`,
							backdrop_path: `https://image.tmdb.org/t/p/original${title.results[0]?.backdrop_path}`,
							mediaType: mediaType,
							tmdbId: title.results[0]?.id
						})
					})
					setMedia([
						...media,
						{
							mediaProvidedBy: 'chatGPT',
							title: `${jsonMatches.category} - Because you liked ${jsonMatches.given_movies[0]}`,
							rowId: media.length + 1,
							titles: newTitles,
							marginPad: Math.floor(Math.random() * 3) * 65
						}
					])
                    setInterstitial(false)
					window.document.getElementsByTagName('body')[0].style.overflowY = '';
				})
			}
		});
    }

    const handleClearList = () => {
        setRecommendationsList([])
    }

    return (
        <>
            <div className="flex flex-col md:flex-row justify-center w-full items-center mb-8">
                <div onClick={handleClearList} className="md:mr-auto text-link">Clear recommendations list</div>
                <div className="">Your Recommendations List</div>
				<div className="md:ml-auto flex flex-col md:items-end items-center">
					<span onClick={submitMatchesList} className="text-link">Find Similar Owned Movies</span>
					<span onClick={submitRecommendationsList} className="text-link">Find Similar Movies</span>
				</div>
            </div>
            <div className="flex flex-wrap justify-center w-full">
                {recommendationsList.map((rec, i) =>
                    <div className="flex justify-center w-full p-2 border odd:border-gray-500 even:border-gray-400" key={i}>{rec}</div>
                )}
            </div>
        </>
    )
}

export default Lists;