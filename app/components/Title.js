import { useContext } from "react";

import { PlexContext } from "./App";

const Title = ({
    mediaProvidedBy,
    addedAt,
    art,
    audienceRating,
    audienceRatingImage,
    contentRating,
    duration,
    guid,
    lastViewedAt,
    originallyAvailableAt,
    primaryExtraKey,
    rating,
    ratingImage,
    ratingKey,
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
    poster_path
}) => {
    const {
        plexServerApiToken,
        plexServerIP,
        plexServerPort,
    } = useContext(PlexContext)

    let imageSrc;
    switch(mediaProvidedBy){
        case 'chatGPT':
            imageSrc = Math.random() > 0.66 ? backdrop_path : poster_path;
            break;
        case 'plex':
            imageSrc = `https://${plexServerIP}:${plexServerPort}/library/metadata/${ratingKey}/${Math.random() > 0.33 ? 'thumb' : 'art'}?X-Plex-Token=${plexServerApiToken}`;
            break;
        default:
            imageSrc = '';
            break;
    }

    return (
        <div className="individual-title relative group hover:cursor-pointer">
            <img src={imageSrc} alt="" className="backgrond-image h-full max-w-[unset] transition-all group-hover:brightness-50" />
            <div className="bottom-title-overlay absolute bottom-0 left-0 flex flex-col justify-center w-full bg-white text-black px-1 py-3 opacity-90 transition-all scale-y-0 origin-bottom group-hover:scale-100">
                <div className="title-overlay-header">
                    <span className="movie-title font-bold mr-4 text-3xl">{title}</span><span className="movie-year">{year}</span>
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