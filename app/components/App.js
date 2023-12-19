import { createContext, useState } from "react";
import classNames from "classnames";
var parseString = require('xml2js').parseString;

import GetPlexConfigs from "./getPlexConfigs";
import Button from "./Button";
import Row from "./Row";

import { plexDataToJson } from '../utils/plex';

export const PlexContext = createContext();

const App = () => {

    const [plexServerIP, setPlexServerIP] = useState(localStorage.getItem('plexServerIP') || '');
    const [plexServerPortDefault, setPlexServerPortDefault] = useState(localStorage.getItem('plexServerPortDefault') == 'true' || true);
    const [plexServerPort, setPlexServerPort] = useState(localStorage.getItem('plexServerPort') || '32400');
    const [plexServerApiToken, setPlexServerApiToken] = useState(localStorage.getItem('plexServerApiToken') || '');
    const [plexConnection, setPlexConnection] = useState(false);
    const [plexLibraries, setPlexLibraries] = useState([]);
    const [media, setMedia] = useState([]);
    const [mediaShown, setMediaShown] = useState([]);

    const [showSettings, setShowSettings] = useState(false);
    const [saveSettingsInBrowser, setSaveSettingsInBrowser] = useState(localStorage.getItem('saveSettingsInBrowser') == 'true' || false)

    const [openAiToken, setOpenAiToken] = useState(localStorage.getItem('openAiToken') || '');
    const [tmdbToken, setTmdbToken] = useState(localStorage.getItem('tmdbToken') || '');

    const getPlexLibraries = () => {
        fetch(`https://${plexServerIP}:${plexServerPort}/library/sections/?X-Plex-Token=${plexServerApiToken}`, {
            method: "GET"
        }).then(response => response.text())
        .then(data => {
            parseString(data, function (err, result) {
                console.log(result);
                const x = result.MediaContainer.Directory;
                setPlexLibraries(x);
            });
            setPlexConnection(true);
        });
    }

    const getPlexLibraryContent = () => {
        const libraryId = document.getElementById('plexLibraries').value;
        const libraryFetched = plexLibraries.filter(lib => String(lib.$.key) == String(libraryId))[0].$
        fetch(`https://${plexServerIP}:${plexServerPort}/library/sections/${libraryId}/all?X-Plex-Token=${plexServerApiToken}`, {
            method: "GET"
        }).then(response => response.text())
        .then(data => {
            parseString(data, function (err, result) {
                const x = result;
                console.log(x);
                // console.log(x.MediaContainer.Video)
                // x.MediaContainer.Video.forEach(title => {console.log(plexDataToJson(title))})
                const newRowTitles = []
                x.MediaContainer.Video.forEach(title => {
                    console.log(title);
                    newRowTitles.push(plexDataToJson(title));
                })
                setMedia([
                    ...media,
                    {   mediaProvidedBy: 'plex',
                        title: `From your Plex Library: ${libraryFetched.title}`,
                        rowId: media.length + 1,
                        titles: newRowTitles
                    }
                ])
            });
        });
    }

    const fetchLibrary = () => {
        console.log(document.getElementById('plexLibraries').value);
    }

    return (
        <PlexContext.Provider value={{
            plexServerIP,
            plexServerPortDefault,
            plexServerPort,
            plexServerApiToken,
            openAiToken,
            tmdbToken,
            saveSettingsInBrowser,
            media,
            setPlexServerIP,
            setPlexServerPortDefault,
            setPlexServerPort,
            setPlexServerApiToken,
            setOpenAiToken,
            setShowSettings,
            setTmdbToken,
            setSaveSettingsInBrowser,
            setMedia
        }}>
            <header className="flex flex-wrap px-[12.5%] py-8 justify-between align-middle bg-black">
                <img src="public/images/plexflix-logo.png" alt="PlexFlix Logo" className="md:w-1/4" />

                <div className="items-center flex justify-center w-full md:w-auto space-x-4 text-white">
                    {Boolean(plexLibraries.length) ?
                        <>
                            <label htmlFor="plexLibraries" className="">Fetch recommendations based on a library:</label>
                            <select name="plexLibraries" id="plexLibraries" className="text-black">
                                {plexLibraries?.map(library => {
                                        return(<option value={library.$.key} key={library.$.title}>{library.$.title}</option>)
                                    })
                                }
                                <option value='all'>All Libraries</option>
                            </select>
                            <Button clickHandler={getPlexLibraryContent} text="Fetch" />
                        </>
                        :
                        <Button clickHandler={getPlexLibraries} text="Get Plex Libraries" />
                    }
                    <div className="group relative flex">
                        <span className="material-symbols-outlined text-4xl hover:text-slate-300 hover:cursor-pointer">info</span>
                        <span className="pointer-events-none absolute border border-gray-500 px-2 py-4 rounded-2xl top-8 max-w-fit lg:-top-4 lg:right-8 bg-slate-100 text-black opacity-0 transition-opacity group-hover:opacity-100">
                            <div className="flex flex-col">
                                {plexServerIP ?
                                    <>
                                        <span className="w-max">Server IP: {plexServerIP}</span>
                                        <span className="w-max">Server Port: {plexServerPort}</span>
                                    </>
                                    :
                                    <span>Enter Plex Server settings to get customized recommendations.</span>
                                }
                            </div>
                        </span>
                    </div>

                    <span className="material-symbols-outlined text-4xl hover:cursor-pointer" onClick={() => setShowSettings(!showSettings)}>settings</span>

                </div>
            </header>
            <div id="body" className="bg-black grow px-[12.5%]">
                {showSettings &&
                    <GetPlexConfigs />
                }

                {Boolean(media?.length) &&
                    media.map((row, i) => 
                        <Row {...row} key={i} />
                    )
                }
            </div>
            <footer className="bg-black text-plexYellow flex justify-center items-center py-4 text-lg"><span className="material-symbols-outlined text-xl">copyright</span><span className=""> PlexFlix {new Date().getFullYear()}</span></footer>

        </PlexContext.Provider>
    )
}

export default App;
