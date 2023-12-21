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
	const [imagesLoaded, setImagesLoaded] = useState(0);
	const mediaTitle = mediaType == 'show' ? 'Show' : 'Movie'

	const getMovieRecommendations = () => {
		setIsLoadingRecommendations(true);
		const titlesArray = titles.map(title => title.title);
		const fetchedRecommendations = fetchChatGptRecommendations(openAiToken, titlesArray);
		fetchedRecommendations.then(data => {
			const stopReason = data.choices[0].finish_reason;
			const recommendations = data.choices[0].message.content.replace('```json','').replace('```','');
			console.log(recommendations)
			const jsonRecs = JSON.parse(recommendations.replace('```json','').replace('```',''))
			if (stopReason === 'stop') {
				const eachPromises = jsonRecs.map(recommendation => {
					const promises = recommendation.suggested_movies.map(movie => {
						return fetch(`https://api.themoviedb.org/3/search/${mediaType == 'show' ? 'tv' : 'movie'}?query=${movie}&include_adult=false&language=en-US&page=1&api_key=${tmdbToken}`, {
							method: "GET",
							headers: {
								accept: 'application/json'
							}
						}).then(res => res.json());
					})
					return Promise.all(promises).then(values => {
						const newTitles = []
						values.map(title => {
							newTitles.push({
								title: title.results[0]?.[mediaType == 'show' ? 'original_name' : 'original_title'],
								tagline: '',
								year: title.results[0]?.[mediaType == 'show' ? 'first_air_date' : 'release_date'].substr(0, 4),
								poster_path: `https://image.tmdb.org/t/p/original${title.results[0]?.poster_path}`,
								backdrop_path: `https://image.tmdb.org/t/p/original${title.results[0]?.backdrop_path}`
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
			{/* <div id="curtain" className={classNames(
			"absolute",
			"left-0",
			"top-0",
			"w-full",
			"h-full",
			"flex",
			"justify-center",
			"items-center",
			"bg-black",
			"z-50",
			{'hidden': imagesLoaded > titles.length / 4}
			)}><button type="button" className="inline-flex items-center px-4 py-2 font-semibold leading-6 text-sm shadow rounded-md text-white bg-plexYellow hover:bg-plexYellowHover transition ease-in-out duration-150 cursor-not-allowed" disabled="">
			<svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
			  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
			  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
			</svg>
			Loading...
		  </button></div> */}
			<div className="py-4 pl-[10%]">
				<span className="text-3xl mr-4">{title}</span>{mediaProvidedBy === 'plex-library' && <Button clickHandler={getMovieRecommendations} text={isLoadingRecommendations ? "Loading recommendations..." : `Get ${mediaTitle} Recommendations`} />}
			</div>
			<div id={`media-tray-${rowId}`} className='p-4 flex overflow-scroll h-80 space-x-8 scrollbar-hide'>
				{titles.map((title, i) =>
					<Title
						{...title}
						mediaProvidedBy={mediaProvidedBy}
						imagesLoaded={imagesLoaded}
						setImagesLoaded={setImagesLoaded}
						key={i}
					/>
				)}
			</div>
		</div>
	)
}

export default Row;