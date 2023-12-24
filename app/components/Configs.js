import { useContext, useState } from "react";
import classNames from "classnames";

import { PlexContext } from "./App";

import Button from "./Button";
import Input from "./Input";

const Configs = () => {

	const {
        plexServerIP,
        plexServerPortDefault,
        plexServerPort,
        plexServerApiToken,
        radarrServerIP,
        radarrServerPortDefault,
        radarrServerPort,
        radarrServerApiToken,
        sonarrServerIP,
        sonarrServerPortDefault,
        sonarrServerPort,
        sonarrServerApiToken,
        openAiToken,
        tmdbToken,
        saveSettingsInBrowser,
        setPlexServerIP,
        setPlexServerPortDefault,
        setPlexServerPort,
        setPlexServerApiToken,
        setRadarrServerIP,
        setRadarrServerPortDefault,
        setRadarrServerPort,
        setRadarrServerApiToken,
        setSonarrServerIP,
        setSonarrServerPortDefault,
        setSonarrServerPort,
        setSonarrServerApiToken,
        setOpenAiToken,
        setTmdbToken,
        setInterstitial,
        setShowSettings,
        setSaveSettingsInBrowser,
        setToast
    } = useContext(PlexContext)

    const [showPlexSettings, setShowPlexSettings] = useState(false);
    const [showOpenAiSettings, setShowOpenAiSettings] = useState(false);    
    const [showTmdbSettings, setShowTmdbSettings] = useState(false);
    const [showRadarrSettings, setShowRadarrSettings] = useState(false);
    const [showSonarrSettings, setShowSonarrSettings] = useState(false);    

    const clearBrowserSettings = () => {
        localStorage.clear();
        setPlexServerIP('');
        setPlexServerPortDefault(true);
        setPlexServerPort('32400');
        setPlexServerApiToken('');
        setOpenAiToken('');
        setTmdbToken('');
        setSaveSettingsInBrowser(false);
        // setShowSettings(false);
        setTimeout(() => {
            setInterstitial(false);
            window.document.getElementsByTagName('body')[0].style.overflowY = '';
            setToast({
                text: 'Browser Settings Removed'
            })
        }, 175)
    }

    const saveSettings = () => {
        setShowSettings(false)
        setSaveSettingsInBrowser(document.getElementsByName('saveSettingsInBrowser')[0].value)

        if (document.getElementsByName('saveSettingsInBrowser')[0].value) {
            localStorage.setItem('plexServerIP', plexServerIP);
            localStorage.setItem('plexServerPortDefault', plexServerPortDefault);
            localStorage.setItem('plexServerPort', plexServerPort);
            localStorage.setItem('plexServerApiToken', plexServerApiToken);
            localStorage.setItem('radarrServerIP', radarrServerIP);
            localStorage.setItem('radarrServerPortDefault', radarrServerPortDefault);
            localStorage.setItem('radarrServerPort', radarrServerPort);
            localStorage.setItem('radarrServerApiToken', radarrServerApiToken);
            localStorage.setItem('sonarrServerIP', sonarrServerIP);
            localStorage.setItem('sonarrServerPortDefault', sonarrServerPortDefault);
            localStorage.setItem('sonarrServerPort', sonarrServerPort);
            localStorage.setItem('sonarrServerApiToken', sonarrServerApiToken);
            localStorage.setItem('openAiToken', openAiToken);
            localStorage.setItem('tmdbToken', tmdbToken);
            localStorage.setItem('saveSettingsInBrowser', true)
        }
        setTimeout(() => {
            setInterstitial(false);
            window.document.getElementsByTagName('body')[0].style.overflowY = '';
            setToast({
                text: 'Settings Saved!'
            })
        }, 175)
    };

    return (
            <div id="settings" className="">
                <div className="w-full mx-auto my-auto flex justify-center space-y-4 flex-wrap">
                    <div id="plexSettings" onClick={() => setShowPlexSettings(!showPlexSettings)} className="settings-header">
                        Plex Settings
                        <span className={classNames(
                            "material-symbols-outlined",
                            "transition-all",
                            {'-rotate-90': showPlexSettings},
                        )}>
                            arrow_back_ios
                        </span>
                    </div>
                    {showPlexSettings &&
                        <div className={classNames("w-full", "transition-all", "origin-top", {'scale-y-0': !showPlexSettings})}>
                            <label htmlFor="plexServerIP" className="w-full">Local Server IP</label>
                            <Input name="plexServerIP" type="text" width="full" handleChange={setPlexServerIP} value={plexServerIP} />
                        
                            <label htmlFor="plexServerApiToken" className="w-full mt-2">
                                Server API Token
                                <a target="_blank" href="https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/" className="pl-2 text-link">
                                    External Link: How to get a Plex API Token
                                </a>
                            </label>
                            <Input name="plexServerApiToken" classes="mt-2" type="text" width="full " handleChange={setPlexServerApiToken} value={plexServerApiToken} />

                            <div className="w-full lgw-1/2 mt-2 flex justify-start lgjustify-center items-center space-x-4">
                                <label htmlFor="plexServerPortToggle" className="">Default Port 32400?</label>
                                <input type="checkbox" className="" onChange={e => setPlexServerPortDefault(!plexServerPortDefault)} name="plexServerPortToggle" id="plexServerPortToggle" checked={plexServerPortDefault}/>
                            </div>

                            <div className="w-full lgw-1/2 flex justify-start lgjustify-center items-center space-x-4">
                                <label htmlFor="plexServerPort" className="">Non Default Port Number</label>
                                <Input name="plexServerPort" type="text" width="1/2" handleChange={setPlexServerPort} value={plexServerPort} disabled={plexServerPortDefault}/>
                            </div>
                        </div>
                    }

                    <div onClick={() => setShowOpenAiSettings(!showOpenAiSettings)} className="settings-header">
                        Open AI Settings
                        <span className={classNames(
                            "material-symbols-outlined",
                            "transition-all",
                            {'-rotate-90': showOpenAiSettings},
                        )}>
                            arrow_back_ios
                        </span>
                    </div>
                    {showOpenAiSettings &&
                        <div className={classNames("w-full", "transition-all", "origin-top", {'scale-y-0': !showOpenAiSettings})}>
                            <label htmlFor="openAiApiToken" className="w-full">
                                API Token
                                <a target="_blank" href="https://platform.openai.com/docs/overview" className="pl-2 text-link">Signup for an OpenAI Developer Account</a>
                            </label>
                            <Input name="openAiApiToken" type="text" width="full" handleChange={setOpenAiToken}  value={openAiToken}/>
                        </div>
                    }

                    <div onClick={() => setShowTmdbSettings(!showTmdbSettings)} className="settings-header">
                        TMDB Settings
                        <span className={classNames(
                            "material-symbols-outlined",
                            "transition-all",
                            {'-rotate-90': showTmdbSettings},
                        )}>
                            arrow_back_ios
                        </span>
                    </div>
                    {showTmdbSettings &&
                        <div className={classNames("w-full", "transition-all", "origin-top", {'scale-y-0': !showTmdbSettings})}>
                            <label htmlFor="tmdbToken" className="w-full">
                                API Token
                                <a target="_blank" href="https://www.themoviedb.org/" className="pl-2 text-link">The Movie Database</a>
                            </label>
                            <Input name="tmdbToken" type="text" width="full " handleChange={setTmdbToken} value={tmdbToken} />
                        </div>
                    }
                    
                    <div id="radarrSettings" onClick={() => setShowRadarrSettings(!showRadarrSettings)} className="settings-header">
                        Radarr Settings
                        <span className={classNames(
                            "material-symbols-outlined",
                            "transition-all",
                            {'-rotate-90': showRadarrSettings},
                        )}>
                            arrow_back_ios
                        </span>
                    </div>
                    {showRadarrSettings &&
                        <div className={classNames("w-full", "transition-all", "origin-top", {'scale-y-0': !showRadarrSettings})}>
                            <label htmlFor="radarrServerIP" className="w-full">Local Server IP</label>
                            <Input name="radarrServerIP" type="text" width="full" handleChange={setRadarrServerIP} value={radarrServerIP} />
                        
                            <label htmlFor="radarrServerApiToken" className="w-full mt-2">
                                Server API Token
                            </label>
                            <Input name="radarrServerApiToken" classes="mt-2" type="text" width="full " handleChange={setRadarrServerApiToken} value={radarrServerApiToken} />

                            <div className="w-full lgw-1/2 mt-2 flex justify-start lgjustify-center items-center space-x-4">
                                <label htmlFor="radarrServerPortToggle" className="">Default Port 7878?</label>
                                <input type="checkbox" className="" onChange={e => setRadarrServerPortDefault(!radarrServerPortDefault)} name="radarrServerPortToggle" id="radarrServerPortToggle" checked={radarrServerPortDefault}/>
                            </div>

                            <div className="w-full lgw-1/2 flex justify-start lgjustify-center items-center space-x-4">
                                <label htmlFor="radarrServerPort" className="">Non Default Port Number</label>
                                <Input name="radarrServerPort" type="text" width="1/2" handleChange={setRadarrServerPort} value={radarrServerPort} disabled={radarrServerPortDefault}/>
                            </div>
                        </div>
                    }

                    <div id="sonarrSettings" onClick={() => setShowSonarrSettings(!showSonarrSettings)} className="settings-header">
                        Sonarr Settings
                        <span className={classNames(
                            "material-symbols-outlined",
                            "transition-all",
                            {'-rotate-90': showSonarrSettings},
                        )}>
                            arrow_back_ios
                        </span>
                    </div>
                    {showSonarrSettings &&
                        <div className={classNames("w-full", "transition-all", "origin-top", {'scale-y-0': !showSonarrSettings})}>
                            <label htmlFor="sonarrServerIP" className="w-full">Local Server IP</label>
                            <Input name="sonarrServerIP" type="text" width="full" handleChange={setSonarrServerIP} value={sonarrServerIP} />
                        
                            <label htmlFor="sonarrServerApiToken" className="w-full mt-2">
                                Server API Token
                            </label>
                            <Input name="sonarrServerApiToken" classes="mt-2" type="text" width="full " handleChange={setSonarrServerApiToken} value={sonarrServerApiToken} />

                            <div className="w-full lgw-1/2 mt-2 flex justify-start lgjustify-center items-center space-x-4">
                                <label htmlFor="sonarrServerPortToggle" className="">Default Port 8989?</label>
                                <input type="checkbox" className="" onChange={e => setSonarrServerPortDefault(!sonarrServerPortDefault)} name="sonarrServerPortToggle" id="sonarrServerPortToggle" checked={sonarrServerPortDefault}/>
                            </div>

                            <div className="w-full lgw-1/2 flex justify-start lgjustify-center items-center space-x-4">
                                <label htmlFor="sonarrServerPort" className="">Non Default Port Number</label>
                                <Input name="sonarrServerPort" type="text" width="1/2" handleChange={setSonarrServerPort} value={sonarrServerPort} disabled={sonarrServerPortDefault}/>
                            </div>
                        </div>
                    }


                    <div className="flex flex-wrap justify-center md:justify-end w-full">
                        <span className="text-link" onClick={clearBrowserSettings}>Clear saved settings</span>
                        <span className="ml-4">Remember settings for future?</span>
                        <input type="checkbox" name="saveSettingsInBrowser" checked={saveSettingsInBrowser} onChange={() => setSaveSettingsInBrowser(!saveSettingsInBrowser)}/>
                        <Button clickHandler={saveSettings} classes={'grow md:grow-0 mt-2 md:mt-0'} text="Save Settings" />
                    </div>
                </div>
            </div>
    )
}

export default Configs;