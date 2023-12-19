import { useContext } from "react";

import { PlexContext } from "./App";

import Button from "./Button";
import Input from "./Input";

const GetPlexConfigs = () => {

	const {
        plexServerIP,
        plexServerPortDefault,
        plexServerPort,
        plexServerApiToken,
        openAiToken,
        tmdbToken,
        saveSettingsInBrowser,
        setPlexServerIP,
        setPlexServerPortDefault,
        setPlexServerPort,
        setPlexServerApiToken,
        setOpenAiToken,
        setTmdbToken,
        setShowSettings,
        setSaveSettingsInBrowser,
    } = useContext(PlexContext)

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
    }

    const saveSettings = () => {
        setShowSettings(false)
        setSaveSettingsInBrowser(document.getElementsByName('saveSettingsInBrowser')[0].value)

        if (document.getElementsByName('saveSettingsInBrowser')[0].value) {
            localStorage.setItem('plexServerIP', plexServerIP);
            localStorage.setItem('plexServerPortDefault', plexServerPortDefault);
            localStorage.setItem('plexServerPort', plexServerPort);
            localStorage.setItem('plexServerApiToken', plexServerApiToken);
            localStorage.setItem('openAiToken', openAiToken);
            localStorage.setItem('tmdbToken', tmdbToken);
            localStorage.setItem('saveSettingsInBrowser', true)
        }
    };

    return (
        <div id="intersitual" className="text-white flex">
            <div className="bg-black w-[90%] md:w-1/2 m-auto p-8 flex justify-center flex-wrap">
                <div className="flex justify-center w-full">
                    <div className="mr-auto"></div>
                    <div className="font-bold">Update Application API Key Settings</div>
                    <span className="material-symbols-outlined ml-auto text-white text-4xl hover:cursor-pointer" onClick={() => setShowSettings(false)}>close</span>
                </div>
                <div id="settings" className="">
                    <div className="w-full mx-auto my-auto flex justify-center space-y-4 flex-wrap">
                        <label htmlFor="plexServerIP" className="w-full">Enter Plex Server Local IP:</label>
                        <Input name="plexServerIP" type="text" width="full" handleChange={setPlexServerIP} value={plexServerIP} />

                        <label htmlFor="plexServerApiToken" className="w-full">Enter Plex Server API Token:</label>
                        <Input name="plexServerApiToken" type="text" width="full " handleChange={setPlexServerApiToken} value={plexServerApiToken} />

                        <div className="w-full lg:w-1/2 flex justify-start lg:justify-center items-center space-x-4">
                            <label htmlFor="plexServerPortToggle" className="">Does Plex use default 32400 Port?</label>
                            <input type="checkbox" className="" onChange={e => setPlexServerPortDefault(!plexServerPortDefault)} name="plexServerPortToggle" id="plexServerPortToggle" checked={plexServerPortDefault}/>
                        </div>

                        <div className="w-full lg:w-1/2 flex justify-start lg:justify-center items-center space-x-4">
                            <label htmlFor="plexServerPort" className="">Enter Plex Port:</label>
                            <Input name="plexServerPort" type="text" width="1/2" handleChange={setPlexServerPort} value={plexServerPort} disabled={plexServerPortDefault}/>
                        </div>

                        <label htmlFor="openAiApiToken" className="w-full">Enter Open AI API Token:</label>
                        <Input name="openAiApiToken" type="text" width="full" handleChange={setOpenAiToken}  value={openAiToken}/>

                        <label htmlFor="tmdbToken" className="w-full">Enter TMDB API Token:</label>
                        <Input name="tmdbToken" type="text" width="full " handleChange={setTmdbToken} value={tmdbToken} />

                        <div className="flex justify-end w-full">
                            <span className="underline text-plexYellow hover:text-plexYellowHover hover:cursor-pointer" onClick={clearBrowserSettings}>Clear saved settings</span>
                            <span className="ml-4">Remember settings for future?</span>
                            <input type="checkbox" name="saveSettingsInBrowser" checked={saveSettingsInBrowser} onChange={() => setSaveSettingsInBrowser(!saveSettingsInBrowser)}/>
                            <Button clickHandler={saveSettings} text="Save Settings" />
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default GetPlexConfigs;