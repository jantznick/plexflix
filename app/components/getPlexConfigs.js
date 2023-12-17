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
        setOpenAiToken
    } = useContext(PlexContext)

    return (
        <form onSubmit={() => setHasConfigs(true)} className="w-full mx-auto flex justify-center space-y-4 flex-wrap">
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

            <button className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline" onClick={() => setHasConfigs(true)} type="button">Submit</button>
        </form>
    )
}

export default GetPlexConfigs;