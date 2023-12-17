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
        setPlexServerIP,
        setPlexServerPortDefault,
        setPlexServerPort,
        setPlexServerApiToken,
        setHasConfigs,
        setOpenAiToken,
        setShowSettings
    } = useContext(PlexContext)

    const saveSettings = () => {
        setHasConfigs(true)
        setShowSettings(false)
    };

    return (
        <div id="intersitual" className="text-white flex">
            <div className="bg-black w-1/2 m-auto p-8 flex justify-center flex-wrap">
                <div className="flex justify-center w-full">
                    <div className="mr-auto"></div>
                    <div className="font-bold">Update Application API Key Settings</div>
                    <span className="material-symbols-outlined ml-auto text-white text-4xl hover:cursor-pointer" onClick={() => setShowSettings(false)}>close</span>
                </div>
                <div id="settings" className="">
                    <div className="w-full mx-auto my-auto flex justify-center space-y-4 flex-wrap">
                        <label htmlFor="plexServerIP" className="w-full">Enter Plex Server Local IP:</label>
                        <Input name="plexServerIP" type="text" width="full" onChange={setPlexServerIP} />

                        <label htmlFor="plexServerApiToken" className="w-full">Enter Plex Server API Token:</label>
                        <Input name="plexServerApiToken" type="text" width="full " onChange={setPlexServerApiToken} />

                        <label htmlFor="plexServerPortToggle" className="w-1/4">Does Plex use default 32400 Port?</label>
                        <input type="checkbox" className="w-1/4" onChange={e => setPlexServerPortDefault(!plexServerPortDefault)} name="plexServerPortToggle" id="plexServerPortToggle" checked={plexServerPortDefault}/>

                        <label htmlFor="plexServerPort" className="w-1/4">Enter Plex Port:</label>
                        <Input name="plexServerPort" type="text" width="1/4" onChange={setPlexServerPort} value={plexServerPort} disabled={plexServerPortDefault}/>

                        <label htmlFor="openAiApiToken" className="w-full">Enter Open AI API Token:</label>
                        <input name="openAiApiToken" type="text" onChange={e => setOpenAiToken(e.target.value)} className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />

                        <div className="flex justify-end w-full">
                            <Button clickHandler={saveSettings} text="Save Settings" />
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default GetPlexConfigs;