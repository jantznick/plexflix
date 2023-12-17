import { createContext, useState } from "react";
import classNames from "classnames";
var parseString = require('xml2js').parseString;

import GetPlexConfigs from "./getPlexConfigs";

export const PlexContext = createContext();

const App = () => {

    const [plexServerIP, setPlexServerIP] = useState('');
    const [plexServerPortDefault, setPlexServerPortDefault] = useState(true);
    const [plexServerPort, setPlexServerPort] = useState('32400');
    const [plexServerApiToken, setPlexServerApiToken] = useState('');
    const [hasConfigs, setHasConfigs] = useState(false);
    const [plexConnection, setPlexConnection] = useState(false);
    const [plexLibraries, setPlexLibraries] = useState();

    const [showSettings, setShowSettings] = useState(false);

    const [openAiToken, setOpenAiToken] = useState('');

    const getPlexLibraries = () => {
        fetch(`http://${plexServerIP}:${plexServerPort}/library/sections/?X-Plex-Token=${plexServerApiToken}`, {
            method: "GET"
        }).then(response => response.text())
        .then(data => {
            parseString(data, function (err, result) {
                const x = result.MediaContainer.Directory
                setPlexLibraries(x)
            });
            setPlexConnection(true);
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
            setOpenAiToken,
            setShowSettings
        }}>
            <header className="flex px-[12.5%] py-8 justify-between align-middle bg-black">
                <img src="public/images/plexflix-logo.png" alt="PlexFlix Logo" className="h-12" />

                <div className="items-center flex space-x-4 text-white">
                    {plexLibraries &&
                        <>
                            <label htmlFor="plexLibraries" className="">Fetch recommendations based on a library:</label>
                            <select name="plexLibraries">
                                {plexLibraries?.map(library => {
                                        return(<option value={library.$.key} key={library.$.title}>{library.$.title}</option>)
                                    })
                                }
                            </select>
                        </>
                    }
                        Server IP: {plexServerIP ? plexServerIP : 'Please enter Plex Server IP in settings'} <span className={classNames(
                            "material-symbols-outlined",
                            {"text-green-400": plexConnection},
                            {"text-red-500": !plexConnection}
                        )}>{plexConnection ? 'check_circle' : 'warning'}</span> | Server Port: {plexServerPort} | 
                        <span className="material-symbols-outlined text-4xl hover:cursor-pointer" onClick={() => setShowSettings(!showSettings)}>settings</span>
                </div>
            </header>
            <div id="body" className="bg-black grow px-[12.5%]">
                {showSettings &&
                    <GetPlexConfigs />
                }
                <button className="bg-plexYellow hover:bg-plexYellowHover text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline" onClick={getPlexLibraries}>Get Plex Libraries</button>
                <button className="bg-plexYellow hover:bg-plexYellowHover text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline" onClick={getMovieRecommendations}>Get Movie Recommendations</button>

            </div>
            <footer className="bg-black text-plexYellow flex justify-center items-center py-4 text-lg"><span className="material-symbols-outlined text-xl">copyright</span><span className=""> PlexFlix {new Date().getFullYear()}</span></footer>

        </PlexContext.Provider>
    )
}

export default App;