import { createContext, useState, useEffect, useRef } from "react";
import classNames from "classnames";

import Interstitial from "./Interstitial";
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
import { seedMedia } from "../utils/seedMedia";

export const PlexContext = createContext();

const useOnScreen = (ref) => {
    const [isOnScreen, setIsOnScreen] = useState(false);
    const observerRef = useRef(null);

    useEffect(() => {
        observerRef.current = new IntersectionObserver(([entry]) => {
            setIsOnScreen(entry.isIntersecting)
        });
    }, []);

    useEffect(() => {
        observerRef.current.observe(ref.current);

        return () => {
            observerRef.current.disconnect();
        };
    }, [ref]);

    return isOnScreen;
}

const App = () => {
    const triggerRef = useRef(null);
    const isOnScreen = useOnScreen(triggerRef);

    const [plexServerIP, setPlexServerIP] = useState(localStorage.getItem('plexServerIP') || '');
    const [plexServerPortDefault, setPlexServerPortDefault] = useState(localStorage.getItem('plexServerPortDefault') == 'true' || true);
    const [plexServerPort, setPlexServerPort] = useState(localStorage.getItem('plexServerPort') || '32400');
    const [plexServerApiToken, setPlexServerApiToken] = useState(localStorage.getItem('plexServerApiToken') || '');
    const [plexLibraries, setPlexLibraries] = useState([]);
    const [media, setMedia] = useState(seedMedia);
    const [mediaShown, setMediaShown] = useState([]);
    const [autoLoad, setAutoLoad] = useState(false);
    const [recommendationsList, setRecommendationsList] = useState([]);

    const [showSettings, setShowSettings] = useState(false);
    const [interstitial, setInterstitial] = useState(false)
    const [interstitialSlug, setInterstitialSlug] = useState('');
    const [saveSettingsInBrowser, setSaveSettingsInBrowser] = useState(localStorage.getItem('saveSettingsInBrowser') == 'true' || false)

    const [openAiToken, setOpenAiToken] = useState(localStorage.getItem('openAiToken') || '');
    const [tmdbToken, setTmdbToken] = useState(localStorage.getItem('tmdbToken') || '');

    // TODO: add this plex most watchlisted thing back in
    const handleFetchWatchlist = () => {
        const fetchResult = getPlexMostWatchlisted(plexServerApiToken)
        fetchResult.then(result => {
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
                    title: `${(randomServiceType.slug == 'watchlist' ? `${service.name}: ` : '')}${result.MediaContainer.title}`,
                    rowId: media.length + 1,
                    titles: result.MediaContainer.Metadata
                }
            ])
        })
    }

    const fetchRandomPlaylist = () => {
        console.log('fetching playlist');
        [handleRandomPlexlist, handleRandomPlexlistServiceType][Math.floor(Math.random() * 2)]();
    }


    if (isOnScreen) {
        // fetchRandomPlaylist()
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
            autoLoad,
            recommendationsList,
            setAutoLoad,
            setPlexServerIP,
            setPlexServerPortDefault,
            setPlexServerPort,
            setPlexServerApiToken,
            setPlexLibraries,
            setOpenAiToken,
            setShowSettings,
            setTmdbToken,
            setSaveSettingsInBrowser,
            setMedia,
            setInterstitial,
            setInterstitialSlug,
            setRecommendationsList
        }}>
            <Header />
            <div id="body" className="bg-black grow px-[12.5%] pb-8">
                {interstitial &&
                    <Interstitial slug={interstitialSlug} />
                }

                {Boolean(media?.length) &&
                    media.map((row, i) =>
                        <Row {...row} key={i} />
                    )
                }

                <div id="reloadTrigger" ref={triggerRef} className="flex justify-center mt-8">
                </div>
            </div>
            <footer className="bg-black fixed w-full bottom-0 text-plexYellow flex justify-center items-center py-4 text-lg"><span className="material-symbols-outlined text-xl">copyright</span><span className=""> PlexFlix {new Date().getFullYear()}</span><a className="ml-8 flex items-center" href="https://github.com/jantznick/plexflix" target="_blank">Github<span className="material-symbols-outlined ml-1">open_in_new</span></a></footer>

        </PlexContext.Provider>
    )
}

export default App;
