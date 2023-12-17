import { useContext } from "react";

import { PlexContext } from "./App";

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
                    <form onSubmit={() => setHasConfigs(true)} className="w-full mx-auto my-auto flex justify-center space-y-4 flex-wrap">
                        <label htmlFor="plexServerIP" className="w-full">Enter Plex Server Local IP:</label>
                        <input name="plexServerIP" type="text" onChange={e => setPlexServerIP(e.target.value)} className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />

                        <label htmlFor="plexServerApiToken" className="w-full">Enter Plex Server API Token:</label>
                        <input name="plexServerApiToken" type="text" onChange={e => setPlexServerApiToken(e.target.value)} className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />

                        <label htmlFor="plexServerPortToggle" className="w-1/4">Does Plex use default 32400 Port?</label>
                        <input type="checkbox" className="w-1/4" onChange={e => setPlexServerPortDefault(!plexServerPortDefault)} name="plexServerPortToggle" id="plexServerPortToggle" checked={plexServerPortDefault}/>

                        <label htmlFor="plexServerPort" className="w-1/4">Enter Plex Port:</label>
                        <input name="plexServerPort" type="text" onChange={e => setPlexServerPort(e.target.value)} className="shadow appearance-none border rounded w-1/4 py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" value={plexServerPort} disabled={plexServerPortDefault}/>

                        <label htmlFor="openAiApiToken" className="w-full">Enter Open AI API Token:</label>
                        <input name="openAiApiToken" type="text" onChange={e => setOpenAiToken(e.target.value)} className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline" />

                        <div className="flex justify-end w-full">
                            <button className="bg-plexYellow hover:bg-plexYellowHover text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline" onClick={saveSettings} type="button">Save Settings</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    )
}

export default GetPlexConfigs;