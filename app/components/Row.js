import { useContext, useState, useEffect } from "react";
import classNames from "classnames";

import Title from "./Title";
import Button from "./Button";

import { PlexContext } from "./App";

import { fetchChatGptRecommendations } from '../utils/openAi';

const Row = ({ title, titles, mediaProvidedBy, mediaType, rowId, marginPad }) => {
	const {
		openAiToken,
		tmdbToken,
		setMedia,
		media,
	} = useContext(PlexContext)

	// useEffect(() => {
	// 	window.document.getElementById(`media-tray-${rowId}`).scrollTo({
	// 		left: marginPad,
	// 		behavior: "instant"
	// 	})
	// })

	const [isLoadingRecommendations, setIsLoadingRecommendations] = useState(false);

	const getMovieRecommendations = () => {
		setIsLoadingRecommendations(true);
		const titlesArray = titles.map(title => title.title);
		const fetchedRecommendations = fetchChatGptRecommendations(openAiToken, titlesArray);
		fetchedRecommendations.then(({stopReason, jsonRecs}) => {
			if (stopReason === 'stop') {
				const eachPromises = jsonRecs.map((recommendation, i1) => {
					const promises = recommendation.suggested_movies.map(movie => {
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
							title: `${recommendation.category} - Because you watched ${recommendation.given_movies[0]}`,
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
				})
			}
		});
		setIsLoadingRecommendations(false);
	}

	return (
		<div id="row" className="text-white relative">
			<div className="py-4 pl-[10%]">
				<span className="text-3xl mr-4">{title}</span>{mediaProvidedBy === 'plex-library' && <Button clickHandler={getMovieRecommendations} text={isLoadingRecommendations ? "Loading recommendations..." : `Get ${mediaType} Recommendations`} />}
			</div>
			<div id={`media-tray-${rowId}`} className='p-4 flex overflow-scroll space-x-12 scrollbar-hide'>
				{titles.map((title, i) =>
					<Title
						{...title}
						mediaProvidedBy={mediaProvidedBy}
						key={i}
						titleKey={i}
						rowKey={rowId}
					/>
				)}
			</div>
		</div>
	)
}

export default Row;