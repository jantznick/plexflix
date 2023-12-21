import { useContext } from "react";

import { PlexContext } from "./App";
import Button from "./Button";

import { fetchChatGptRecommendations } from '../utils/openAi';

const Lists = () => {
    const {
        recommendationsList,
        setRecommendationsList,
        setMedia,
        openAiToken,
        tmdbToken,
        media,
        setInterstitial
	} = useContext(PlexContext)

    const submitRecommendationsList = () => {
		const fetchedRecommendations = fetchChatGptRecommendations(openAiToken, recommendationsList);
		fetchedRecommendations.then(data => {
			const stopReason = data.choices[0].finish_reason;
			const recommendations = JSON.parse(data.choices[0].message.content);
			console.log(recommendations)
			if (stopReason === 'stop') {
				const eachPromises = recommendations.map(recommendation => {
					const promises = recommendation.suggested_movies.map(movie => {
						return fetch(`https://api.themoviedb.org/3/search/movie?query=${movie}&include_adult=false&language=en-US&page=1&api_key=${tmdbToken}`, {
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
								title: title.results[0]?.['original_title'],
								tagline: '',
								year: title.results[0]?.['release_date'].substr(0, 4),
								poster_path: `https://image.tmdb.org/t/p/original${title.results[0]?.poster_path}`,
								backdrop_path: `https://image.tmdb.org/t/p/original${title.results[0]?.backdrop_path}`
							})
						})
						return {
							mediaProvidedBy: 'chatGPT',
							title: `${recommendation.category} - Because you liked ${recommendation.given_movies[0]}`,
							rowId: media.length + 1,
							titles: newTitles
						}
					})
				})
				Promise.all(eachPromises).then(values => {
					setMedia([
						...media,
						...values
					])
                    setInterstitial(false)
				})
			}
		});
    }

    const handleClearList = () => {
        setRecommendationsList([])
    }

    return (
        <>
            <div className="flex justify-center w-full items-center mb-8">
                <div onClick={handleClearList}className="mr-auto text-plexYellow hover:cursor-pointer hover:text-plexYellowHover">Clear recommendations list</div>
                <div className="">Your Recommendations List</div>
                <Button clickHandler={submitRecommendationsList} text={'Submit List'} classes="ml-auto"/>
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