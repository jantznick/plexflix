import { useContext, useState, useEffect } from "react";
import classNames from "classnames";

import { PlexContext } from "./App";

import Button from "./Button";

import { searchTmdb } from '../utils/tmdb';

const Header = () => {

    const {
        media,
		plexLibraries,
        plexServerIP,
        plexServerPort,
        plexServerApiToken,
        showSettings,
        plexTitles,
        tmdbToken,
        recommendationsList,
        setPlexLibraries,
        setInterstitial,
        setInterstitialSlug,
        setMedia,
        setPlexTitles,
        setUnwatchedPlexTitles,
        setRecommendationsList,
        unwatchedPlexTitles
	} = useContext(PlexContext)

    const [separateByGenre, setSeparateByGenre] = useState(false);
    const [searchTerm, setSearchTerm] = useState('');
    const [searchDropDown, setSearchDropDown] = useState([]);
    const [searchType, setSearchType] = useState('movie');

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
            // TODO: Switch this to the same big promise thing in Lists.js so we can set unwatched titles and watched titles and eventually sort genres
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
            const unwatchedNames = unwatchedTitles.map((title) => title.title);
            setUnwatchedPlexTitles([
                ...unwatchedPlexTitles,
                ...unwatchedNames
            ])
            const watchedTitles = data.MediaContainer.Metadata.filter((title) => title.lastViewedAt)
            console.log(unwatchedTitles);
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

    const handleSearchChange = (e) => {
        setSearchTerm(e.target.value);
        if (e.target.value.length > 5){
            // TODO: Fix this isn't quite ready to handle the return value being tv shows called 'name' but movies called 'title'
            searchTmdb(tmdbToken, e.target.value, 'movie').then(data => {
                setSearchDropDown(data.results)
            })
        }
    }

    const addToList = (title) => {
        if (!recommendationsList.includes(title)) {
            setRecommendationsList([
                ...recommendationsList,
                title
            ])
        } else {
            setRecommendationsList([...recommendationsList.filter(item => item != title)])
        }
    }

    const switchSearchType = () => {
        setSearchType(searchType == 'movie' ? 'tv' : 'movie')
    }

    return (
        <header className="flex flex-wrap px-[12.5%] py-8 justify-between align-middle bg-black">
            <img src="public/images/plexflix-logo.png" alt="PlexFlix Logo" className="md:w-1/4" />

            <div className="items-center flex justify-center w-full md:w-auto space-x-4 text-white">
                <form action="" className={classNames(
                    "flex",
                    "bg-white",
                    "rounded-t-md",
                    "rounded-br-md",
                    "text-black",
                    "items-center",
                    {"rounded-bl-md": !searchDropDown.length}
                )}>
                    <div onClick={switchSearchType} className="p-2 border-r-2 border-gray-400 hover:cursor-pointer">{searchType == 'movie' ? 'Movie' : 'TV Show'}</div>
                    <div id="searchInput" className="flex flex-col relative">
                        <div id="searchBox" className="p-2">
                            <input type="text" name="searchTerm" onChange={handleSearchChange} placeholder="Search..." value={searchTerm} className="transition-all focus-visible:outline-none min-w-[25vw]" />
                        </div>
                        <div id="dropDown" className={classNames(
                            "absolute",
                            "bg-white",
                            "w-full",
                            "overflow-scroll",
                            "z-50",
                            "max-h-32",
                            "top-10",
                            "rounded-b-md",
                            "transition-all",
                            "origin-top",
                            "scrollbar-hide",
                            {"scale-y-0": !searchDropDown.length},
                        )}>
                            {searchDropDown.length &&
                                searchDropDown.map((result, i) =>
                                    <div id={`dropDownOption${i}`} key={i} className="p-2 pr-8 relative odd:bg-gray-200">
                                        {result.title}
                                        <div onClick={() => addToList(result.title)} className={classNames(
                                            "absolute",
                                            "right-4",
                                            "top-2",
                                            "rounded-sm",
                                            "text-black",
                                            "hover:cursor-pointer"
                                        )}>
                                            <span className="material-symbols-outlined px-1">
                                                {recommendationsList.includes(result.title) ? 'shadow_minus' : 'library_add'}
                                            </span>
                                        </div>
                                    </div>
                                )
                            }
                        </div>
                    </div>
                    <span className="material-symbols-outlined px-2 hover:cursor-pointer">search</span>
                </form>
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