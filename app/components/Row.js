import { useContext, useState } from "react";

import Title from "./Title";
import Button from "./Button";

import { PlexContext } from "./App";

import { recomendMessages } from '../utils/openAi';

const Row = ({ title, titles, mediaProvidedBy }) => {

	const {
		openAiToken,
		tmdbToken,
		setMedia,
		media
	} = useContext(PlexContext)

	const [isLoadingRecommendations, setIsLoadingRecommendations] = useState(false);

	const getMovieRecommendations = () => {
		setIsLoadingRecommendations(true);
		const titlesArray = titles.map(title => title.title);
		// console.log(titlesArray);
		fetch('https://api.openai.com/v1/chat/completions', {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				"Authorization": `Bearer ${openAiToken}`
			},
			body: JSON.stringify({
				"model": "gpt-3.5-turbo",
				"messages": recomendMessages(titlesArray)
			})
		}).then(response => response.json())
			.then(data => {
				const stopReason = data.choices[0].finish_reason;
				const recommendations = JSON.parse(data.choices[0].message.content);
				console.log(recommendations);
				if (stopReason === 'stop') {
					console.log('gonna loop through recommendations and add to media now')

					const newMedia = [];
					recommendations.forEach(recommendation => {
						console.log(`looping through recommendation ${recommendation.category}`)
						const promises = recommendation.suggested_movies.map(movie => {
							return fetch(`https://api.themoviedb.org/3/search/movie?query=${movie}&include_adult=false&language=en-US&page=1&api_key=${tmdbToken}`, {
								method: "GET",
								headers: {
									accept: 'application/json'
								}
							}).then(res => res.json());
						})
						Promise.all(promises).then(values => {
							console.log(values);
							const newTitles = []
							values.map(title => {
								newTitles.push({
									title: title.results[0].original_title,
									tagline: '',
									year: title.results[0].release_date.substr(0, 4),
									poster_path: `https://image.tmdb.org/t/p/original${title.results[0].poster_path}`,
									backdrop_path: `https://image.tmdb.org/t/p/original${title.results[0].backdrop_path}`
								})
							})
							newMedia.push({
								mediaProvidedBy: 'chatGPT',
								title: `${recommendation.category} - Because you watched ${recommendation.given_movies[0]}`,
								rowId: media.length + 1,
								titles: newTitles
							})
						})
						// console.log(`looping through recommendation ${recommendation.category}`)
						// const newRow = {}
						// newRow.mediaProvidedBy = 'chatGPT';
						// newRow.title = `${recommendation.category} - Because you watched ${recommendation.given_movies[0]}`;
						// newRow.rowId = media.length + 1;
						// const newRowTitles = [];
						// recommendation.suggested_movies.forEach(movie => {
						// 	console.log(movie);
						// 	fetch(`https://api.themoviedb.org/3/search/movie?query=${movie}&include_adult=false&language=en-US&page=1&api_key=${tmdbToken}`, {
						// 		method: "GET",
						// 		headers: {
						// 			accept: 'application/json'
						// 		}
						// 	}).then(response => response.json())
						// 	.then(json => {
						// 		console.log(json);
						// 		const movieData = json.results[0]
						// 		newRowTitles.push({
						// 			title: movieData.original_title,
						// 			tagline: '',
						// 			year: movieData.release_date.substr(0, 4),
						// 			poster_path: `https://image.tmdb.org/t/p/original${movieData.poster_path}`,
						// 			backdrop_path: `https://image.tmdb.org/t/p/original${movieData.backdrop_path}`
						// 		})
						// 	})
						// })
						// newRow.titles = newRowTitles;
						// console.log(`setting media ${JSON.stringify(newRow)}`)
						// setMedia([
						// 	...media,
						// 	newRow
						// ])
					})
					console.log(newMedia);
					setMedia([
						...media,
						...newMedia
					])
				}
			});
		setIsLoadingRecommendations(false);
	}

	return (
		<div className="text-white">
			<div className="py-4">
				<span className="text-3xl mr-4">{title}</span>{mediaProvidedBy === 'plex' && <Button clickHandler={getMovieRecommendations} text={isLoadingRecommendations ? "Loading recommendations..." : "Get Movie Recommendations"} />}
			</div>
			<div id="media-tray" className="flex overflow-scroll h-80 space-x-4">
				{titles.map(title =>
					<Title {...title} mediaProvidedBy={mediaProvidedBy} />
				)}
			</div>
		</div>
	)
}

export default Row;