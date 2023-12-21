import { useContext } from "react";

import { PlexContext } from "./App";
import Button from "./Button";

const Lists = () => {
    const {
        recommendationsList,
        setRecommendationsList
	} = useContext(PlexContext)

    const submitRecommendationsList = () => {
        console.log('does nothing yet');
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