import { createContext, useState } from "react";
import classNames from "classnames";
var parseString = require('xml2js').parseString;

import GetPlexConfigs from "./getPlexConfigs";
import Row from "./Row";
import Header from "./Header";
import Button from "./Button";

import {
    getPlexMostWatchlisted,
    getPlexServiceGenres,
    getPopularPlexGenresFromService,
    getPlexServiceRankings,
    services,
    serviceTypes
} from '../utils/plex';

export const PlexContext = createContext();

const App = () => {

    const [plexServerIP, setPlexServerIP] = useState(localStorage.getItem('plexServerIP') || '');
    const [plexServerPortDefault, setPlexServerPortDefault] = useState(localStorage.getItem('plexServerPortDefault') == 'true' || true);
    const [plexServerPort, setPlexServerPort] = useState(localStorage.getItem('plexServerPort') || '32400');
    const [plexServerApiToken, setPlexServerApiToken] = useState(localStorage.getItem('plexServerApiToken') || '');
    const [plexLibraries, setPlexLibraries] = useState([]);
    const [media, setMedia] = useState([]);
    const [mediaShown, setMediaShown] = useState([]);

    const [showSettings, setShowSettings] = useState(false);
    const [saveSettingsInBrowser, setSaveSettingsInBrowser] = useState(localStorage.getItem('saveSettingsInBrowser') == 'true' || false)

    const [openAiToken, setOpenAiToken] = useState(localStorage.getItem('openAiToken') || '');
    const [tmdbToken, setTmdbToken] = useState(localStorage.getItem('tmdbToken') || '');

    const handleFetchWatchlist = () => {
        const fetchResult = getPlexMostWatchlisted(plexServerApiToken)
        fetchResult.then(result => {
            console.log(result)
            setMedia([
                ...media,
                {  
                    mediaType: 'mixed',
                    mediaProvidedBy: 'plex-service',
                    title: `Plex: ${result.MediaContainer.title}`,
                    rowId: media.length + 1,
                    titles: result.MediaContainer.Metadata
                }
            ])
        })
    }

    const handleRandomPlexlist = () => {
        const service = services[Math.floor(Math.random() * services.length)]
        getPopularPlexGenresFromService(plexServerApiToken, service.slug).then(data => {
            const genres = data.MediaContainer.Directory
            const randomGenre = genres[Math.floor(Math.random() * genres.length)]
            const fetchResult = getPlexServiceGenres(plexServerApiToken, service.slug, randomGenre.slug)
            fetchResult.then(result => {
                setMedia([
                    ...media,
                    {  
                        mediaType: 'mixed',
                        mediaProvidedBy: 'plex-service',
                        title: `From ${service.name}: ${result.MediaContainer.title}`,
                        rowId: media.length + 1,
                        titles: result.MediaContainer.Metadata
                    }
                ])
            })
        })
    }

    const handleRandomPlexlistServiceType = () => {
        const service = services[Math.floor(Math.random() * services.length)]
        const randomServiceType = serviceTypes[Math.floor(Math.random() * serviceTypes.length)]
        const fetchResult = getPlexServiceRankings(plexServerApiToken, service.slug, randomServiceType.slug)
        fetchResult.then(result => {
            setMedia([
                ...media,
                {  
                    mediaType: 'mixed',
                    mediaProvidedBy: 'plex-service',
                    title: `${(randomServiceType.slug == 'watchlist' ? `${service.name}: ` : '' )}${result.MediaContainer.title}`,
                    rowId: media.length + 1,
                    titles: result.MediaContainer.Metadata
                }
            ])
        })
    }

    const fetchRandomPlaylist = () => {
        [handleRandomPlexlist, handleRandomPlexlistServiceType][Math.floor(Math.random() * 2)]()
    }

    return (
        <PlexContext.Provider value={{
            plexServerIP,
            plexServerPortDefault,
            plexServerPort,
            plexServerApiToken,
            plexLibraries,
            openAiToken,
            tmdbToken,
            saveSettingsInBrowser,
            media,
            setPlexServerIP,
            setPlexServerPortDefault,
            setPlexServerPort,
            setPlexServerApiToken,
            setPlexLibraries,
            setOpenAiToken,
            setShowSettings,
            setTmdbToken,
            setSaveSettingsInBrowser,
            setMedia
        }}>
            <Header />
            <div id="body" className="bg-black grow px-[12.5%] pb-8">
                {showSettings &&
                    <GetPlexConfigs />
                }

                {Boolean(media?.length) &&
                    media.map((row, i) => 
                        <Row {...row} key={i} />
                    )
                }

                <div className="flex justify-center mt-8">
                    <Button clickHandler={handleFetchWatchlist} text="Fetch Plex Trending Watchlist" />
                    <Button clickHandler={fetchRandomPlaylist} text="Fetch Random Playlist" classes="ml-8" />
                </div>
            </div>
            <footer className="bg-black text-plexYellow flex justify-center items-center py-4 text-lg"><span className="material-symbols-outlined text-xl">copyright</span><span className=""> PlexFlix {new Date().getFullYear()}</span></footer>

        </PlexContext.Provider>
    )
}

export default App;
