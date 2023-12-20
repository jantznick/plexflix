import { useContext, useState } from "react";

var parseString = require('xml2js').parseString;

import { PlexContext } from "./App";

import Button from "./Button";

const Header = () => {

    const {
        media,
		plexLibraries,
        plexServerIP,
        plexServerPort,
        plexServerApiToken,
        showSettings,
        setPlexLibraries,
        setShowSettings,
        setMedia
	} = useContext(PlexContext)

    const getPlexLibraryContent = () => {
        const libraryId = document.getElementById('plexLibraries').value;
        // const libraryFetched = plexLibraries.filter(lib => String(lib.key) == String(libraryId))[0].$
        fetch(`https://${plexServerIP}:${plexServerPort}/library/sections/${libraryId}/all?X-Plex-Token=${plexServerApiToken}`, {
            method: "GET",
            headers: {
                "accept": "application/json, text/plain, */*",
            },
        }).then(response => response.json())
        .then(data => {
            console.log(data)
            setMedia([
                ...media,
                {  
                    mediaType: data.MediaContainer.viewGroup,
                    mediaProvidedBy: 'plex-library',
                    title: `From your Plex Library: ${data.MediaContainer.title1}`,
                    rowId: media.length + 1,
                    titles: data.MediaContainer.Metadata
                }
            ])
        });
    }

    const getPlexLibraries = () => {
        fetch(`https://${plexServerIP}:${plexServerPort}/library/sections/?X-Plex-Token=${plexServerApiToken}`, {
            method: "GET",
            headers: {
                "accept": "application/json, text/plain, */*",
            },
        }).then(response => response.json())
        .then(json => {
            setPlexLibraries(json.MediaContainer.Directory)
        });
    }

    return (
        <header className="flex flex-wrap px-[12.5%] py-8 justify-between align-middle bg-black">
            <img src="public/images/plexflix-logo.png" alt="PlexFlix Logo" className="md:w-1/4" />

            <div className="items-center flex justify-center w-full md:w-auto space-x-4 text-white">
                {Boolean(plexLibraries.length) ?
                    <>
                        <label htmlFor="plexLibraries" className="">Fetch recommendations based on a library:</label>
                        <select name="plexLibraries" id="plexLibraries" className="text-black">
                            {plexLibraries?.map(library => {
                                    return(<option value={library.key} key={library.title}>{library.title}</option>)
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
    )
}

export default Header;