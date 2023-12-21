import { useContext, useState } from "react";

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
        plexTitles,
        recommendationsList,
        setPlexLibraries,
        setInterstitial,
        setInterstitialSlug,
        setMedia,
        setPlexTitles
	} = useContext(PlexContext)

    const [separateByGenre, setSeparateByGenre] = useState(false);

    const getPlexLibraryContent = () => {
        const libraryId = document.getElementById('plexLibraries').value;
        const libraryFetched = plexLibraries.filter(lib => String(lib.key) == String(libraryId))[0].$
        fetch(`https://${plexServerIP}:${plexServerPort}/library/sections/${libraryId}/all?X-Plex-Token=${plexServerApiToken}`, {
            method: "GET",
            headers: {
                "accept": "application/json, text/plain, */*",
            },
        }).then(response => response.json())
        .then(data => {
            // TODO: Switch this to the same big promise thing in Lists.js
            console.log(data)
            setMedia([
                ...media,
                {  
                    mediaType: data.MediaContainer.viewGroup,
                    mediaProvidedBy: 'plex-library',
                    title: `From your Plex Library: ${data.MediaContainer.title1}`,
                    rowId: media.length + 1,
                    titles: data.MediaContainer.Metadata,
                    marginPad: Math.floor(Math.random() * 3) * 65
                }
            ])
            const titles = data.MediaContainer.Metadata.map((title) => title.title)
            setPlexTitles([
                ...plexTitles,
                ...titles
            ])
            const unwatchedTitles = data.MediaContainer.Metadata.filter((title) => !title.lastViewedAt)
            console.log(unwatchedTitles);
            // setMedia([
            //     ...media,
            //     {  
            //         mediaType: data.MediaContainer.viewGroup,
            //         mediaProvidedBy: 'plex-library',
            //         title: `Unwatched in your Plex Library: ${data.MediaContainer.title1}`,
            //         rowId: media.length + 1,
            //         titles: unwatchedTitles,
            //         marginPad: Math.floor(Math.random() * 3) * 65
            //     }
            // ])
            if (separateByGenre) {
                const genres = [];
                const titles = data.MediaContainer.Metadata;

            }
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

    const handleOpenConfigs = () => {
        setInterstitialSlug('configs');
        setInterstitial(true);
    }

    const handleOpenLists = () => {
        setInterstitialSlug('lists');
        setInterstitial(true);
    }

    return (
        <header className="flex flex-wrap px-[12.5%] py-8 justify-between align-middle bg-black">
            <img src="public/images/plexflix-logo.png" alt="PlexFlix Logo" className="md:w-1/4" />

            <div className="items-center flex justify-center w-full md:w-auto space-x-4 text-white">
                {Boolean(recommendationsList.length) && <div  onClick={handleOpenLists} className="text-plexYellow transition-all hover:tracking-widest hover:cursor-pointer hover:text-plexYellowHover hover:font-bold">View Lists ({recommendationsList.length})</div>}
                {Boolean(plexLibraries.length) ?
                    <>
                        {/* <label htmlFor="genreSeparate" className="">Separate by Genre?</label>
                        <input type="checkbox" name="genreSeparate" id="genreSeparate" className="" onChange={e => setSeparateByGenre(!separateByGenre)}  checked={separateByGenre}/> */}
                        <select name="plexLibraries" id="plexLibraries" className="text-black">
                            {plexLibraries?.map(library => {
                                    return(<option value={library.key} key={library.title}>{library.title}</option>)
                                })
                            }
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

                <span className="material-symbols-outlined text-4xl hover:cursor-pointer" onClick={handleOpenConfigs}>settings</span>

            </div>
        </header>
    )
}

export default Header;