import { useContext } from "react";
import classNames from "classnames";

import { PlexContext } from "./App";

import { addMovieToRadarr, addShowToSonarr } from '../utils/torrents';
import { searchTmdb, tmdbExternalIds } from '../utils/tmdb';

const Title = ({
    mediaProvidedBy,
    addedAt,
    art,
    audienceRating,
    audienceRatingImage,
    contentRating,
    duration,
    guid,
    tmdbId,
    titleKey,
    mediaType,
    lastViewedAt,
    originallyAvailableAt,
    primaryExtraKey,
    rating,
    ratingImage,
    ratingKey,
    rowKey,
    studio,
    summary,
    tagline,
    thumb,
    title,
    type,
    updatedAt,
    viewCount,
    year,
    country,
    director,
    genre,
    media,
    role,
    writer,
    backdrop_path,
    poster_path,
    Image
}) => {
    const {
        plexServerApiToken,
        plexServerIP,
        plexServerPort,
        recommendationsList,
        plexTitles,
        media:allMedia,
        tmdbToken,
        radarrServerApiToken,
        radarrServerIP,
        radarrServerPort,
        sonarrServerApiToken,
        sonarrServerIP,
        sonarrServerPort,
        unwatchedPlexTitles,
        setRecommendationsList,
        setActiveTitle,
        setInterstitial,
        setInterstitialSlug,
        setToast
    } = useContext(PlexContext)

    let imageSrc;
    switch(mediaProvidedBy){
        case 'chatGPT':
            imageSrc = poster_path;
            break;
        case 'plex-library':
            imageSrc = `https://${plexServerIP}:${plexServerPort}/library/metadata/${ratingKey}/thumb?X-Plex-Token=${plexServerApiToken}`;
            break;
        case 'plex-service':
            imageSrc = thumb;
            break;
        default:
            imageSrc = '';
            break;
    }

    const addToList = () => {
        if (!recommendationsList.includes(title)) {
            setRecommendationsList([
                ...recommendationsList,
                title
            ])
        } else {
            setRecommendationsList([...recommendationsList.filter(item => item != title)])
        }
    }

    const handleChooseTitle = () => {
        setActiveTitle(allMedia[rowKey-1].titles[titleKey])
        setInterstitialSlug('title-page');
        setInterstitial(true);
        window.document.getElementsByTagName('body')[0].style.overflowY = 'hidden';
    }

    const usedMediaType = (mediaType ? mediaType : (type == 'movie' ? 'movie' : 'tv'))

    const handleDownload = () => {
        if (tmdbId && usedMediaType == 'movie') {
            const addToRadarrResult = addMovieToRadarr(radarrServerApiToken, radarrServerIP, radarrServerPort, tmdbId, title)
            addToRadarrResult.then(result => {
                console.log(result)
                setToast({
                    text: `Added movie ${title}`
                })
            })
        } else {
            searchTmdb(tmdbToken, title, usedMediaType).then(data => {
                if (usedMediaType == 'movie') {
                    const addToRadarrResult = addMovieToRadarr(radarrServerApiToken, radarrServerIP, radarrServerPort, data.results[0].id, title)
                    addToRadarrResult.then(result => {
                        console.log(result)
                        if (result.monitored) {
                            setToast({
                                text: `Added movie ${title}`
                            })
                        }
                    })
                } else {
                    console.log(usedMediaType);
                    console.log(data);
                    tmdbExternalIds(tmdbToken, data.results[0].id).then(data => {
                        if (data.tvdb_id) {
                            const addToSonarrResult = addShowToSonarr(sonarrServerApiToken, sonarrServerIP, sonarrServerPort, title, data.tvdb_id)
                            addToSonarrResult.then(result => {
                                console.log(result)
                                setToast({
                                    text: `Added TV Show ${title}`
                                })
                            })
                        } else {
                            setToast({
                                text: `Error adding ${title}, not TVDB ID found`
                            })
                        }
                    })
                }
            })
        }
    }

    return (
        <div className={classNames(
            "individual-title",
            "relative",
            "group",
            {"unwatched": unwatchedPlexTitles.includes(title)},
            {"border-2": plexTitles.includes(title)},
            "border-plexYellow",
            "hover:cursor-pointer"
        )}>
            <div onClick={addToList} className={classNames(
                "absolute",
                "top-2",
                "right-2",
                "p-2",
                "pb-1",
                "rounded-md",
                "text-black",
                "bg-plexYellowTransparent",
                "hover:bg-plexYellowHover",
                "hover:cursor-pointer",
                "z-50",
                {"bg-gray-300": recommendationsList.includes(title)}
            )}>
                <span className="material-symbols-outlined">
                    {recommendationsList.includes(title) ? 'shadow_minus' : 'library_add'}
                </span>
            </div>
            <div onClick={handleDownload} className={classNames(
                "absolute",
                "top-16",
                "right-2",
                "p-2",
                "pb-1",
                "rounded-md",
                "text-black",
                "bg-plexYellowTransparent",
                "hover:bg-plexYellowHover",
                "hover:cursor-pointer",
                "z-50",
            )}>
                <span className="material-symbols-outlined">download</span>
            </div>
            <img src={imageSrc} alt="" onClick={handleChooseTitle} className={classNames(
                "backgrond-image",
                "h-60",
                "lg:h-80",
                "max-w-[unset]",
                "transition-all",
                "group-hover:brightness-50")}
            />
            <div onClick={handleChooseTitle} className="bottom-title-overlay absolute bottom-0 left-0 flex flex-col justify-center w-full bg-white text-black px-1 py-3 opacity-90 transition-all scale-y-0 origin-bottom group-hover:scale-100">
                <div className="title-overlay-header">
                    <span className="movie-title font-bold mr-4 text-2xl">{title}</span><span className="movie-year">{year}</span>
                </div>
                <div className="title-overlay-description">
                    {tagline}
                </div>
            </div>
        </div>
    )
}


// {
//     "addedAt": "1645975073",
//     "art": "/library/metadata/2611/art/1701747979",
//     "audienceRating": "8.5",
//     "audienceRatingImage": "rottentomatoes://image.rating.upright",
//     "contentRating": "PG",
//     "duration": "6133085",
//     "guid": "plex://movie/5d776926ad5437001f7595eb",
//     "key": "/library/metadata/2611",
//     "lastViewedAt": "1702740478",
//     "originallyAvailableAt": "2013-11-20",
//     "primaryExtraKey": "/library/metadata/2613",
//     "rating": "9.0",
//     "ratingImage": "rottentomatoes://image.rating.ripe",
//     "ratingKey": "2611",
//     "studio": "Walt Disney Pictures",
//     "summary": "When the newly crowned Queen Elsa accidentally uses her power to turn things into ice to curse her home in infinite winter, her sister Anna teams up with a mountain man, his playful reindeer, and a snowman to change the weather condition.",
//     "tagline": "Only the act of true love will thaw a frozen heart.",
//     "thumb": "/library/metadata/2611/thumb/1701747979",
//     "title": "Frozen",
//     "type": "movie",
//     "updatedAt": "1701747979",
//     "viewCount": "2",
//     "year": "2013",
//     "country": [
//       "United States of America"
//     ],
//     "director": [
//       "Chris Buck",
//       "Jennifer Lee"
//     ],
//     "genre": [
//       "Adventure",
//       "Animation"
//     ],
//     "media": [
//       "{aspectRatio: \"2.20\", audioChannels: \"2\", audioCode…}",
//       "{audioProfile: \"lc\", container: \"mp4\", duration: \"6…}"
//     ],
//     "role": [
//       "Kristen Bell",
//       "Idina Menzel",
//       "Jonathan Groff"
//     ],
//     "writer": [
//       "Chris Buck",
//       "Hans Christian Andersen"
//     ]
//   },

export default Title;