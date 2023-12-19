import { createContext, useState } from "react";
import classNames from "classnames";

import GetPlexConfigs from "./getPlexConfigs";
import Row from "./Row";
import Header from "./Header";

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
