import { createContext, useState } from "react";
import GetPlexConfigs from "./getPlexConfigs";

export const PlexContext = createContext();

const App = () => {

    const [plexServerIP, setPlexServerIP] = useState('');
    const [plexServerPortDefault, setPlexServerPortDefault] = useState(true);
    const [plexServerPort, setPlexServerPort] = useState('32400');
    const [plexServerApiToken, setPlexServerApiToken] = useState('');
    const [hasConfigs, setHasConfigs] = useState(false);

    const [openAiToken, setOpenAiToken] = useState('');

    const getPlexLibraries = () => {
        fetch(`http://${plexServerIP}:${plexServerPort}/library/sections/?X-Plex-Token=${plexServerApiToken}`, {
            method: "GET"
        }).then(response => {
            console.log(response);
        });
    }

    const getMovieRecommendations = () => {
        fetch('https://api.openai.com/v1/chat/completions', {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${openAiToken}`
            },
            body: JSON.stringify({
                "model": "gpt-3.5-turbo",
                "messages": [
                    {"role": "system", "content": "Given an array of movie names group them based on similarity, if needed, a group can be a single movie but try and group them together if possible. Then provide 5 recommendations of similar movies for each grouping. Give each group a title based on the genre of movies similar to how Netflix categorizes movies and shows." },
                    {"role": "system", "content": "Provide data as a json array of objects with the following format: [{category: '...', given_movies: ['movie 1', 'movie 2', ...], suggested_movies: ['movie 1', 'movie 2', ...]}]"},
                    {"role": "system", "content": "Do not provide any text outside of the given json object"},
                    {"role": "user", "content": "['gone girl', 'the girl on the train', 'die hard', 'crazy rich asians', 'mean girls', 'my cousin vinny', 'no strings attached', 'zodiac', 'sinister' 'first wives club', 'death on the nile']"}
                ]
            })
        }).then(response => response.json())
        .then(data => {
            console.log(data);
        });
    }

    return (
        <PlexContext.Provider value={{
            plexServerIP,
            plexServerPortDefault,
            plexServerPort,
            plexServerApiToken,
            setPlexServerIP,
            setPlexServerPortDefault,
            setPlexServerPort,
            setPlexServerApiToken,
            setHasConfigs,
            setOpenAiToken
        }}>
            <header className="flex justify-between align-middle bg-slate-950">
                <img src="public/images/plexflix-logo.png" alt="PlexFlix Logo" className="h-12" />

                <div className="">
                    {hasConfigs &&
                        <div className="">Server IP: {plexServerIP} | Server Port: {plexServerPort}</div>
                    }
                    {!hasConfigs &&
                        <button className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline">Settings</button>
                    }
                </div>
            </header>
            {!hasConfigs &&
                <GetPlexConfigs />
            }
            <button className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline" onClick={getPlexLibraries}>Get Plex Libraries</button>
            <button className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline" onClick={getMovieRecommendations}>Get Movie Recommendations</button>
        </PlexContext.Provider>
    )
}

export default App;