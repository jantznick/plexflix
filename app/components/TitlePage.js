import { useContext } from "react";
import classNames from "classnames";

import Row from "./Row";

import { PlexContext } from "./App";

const TitlePage = ({
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
    poster_path,
    Image,
}) => {
    const {
        media:allMedia
    } = useContext(PlexContext)

    function msToTime(s) {
        var ms = s % 1000;
        s = (s - ms) / 1000;
        var secs = s % 60;
        s = (s - secs) / 60;
        var mins = s % 60;
        var hrs = (s - mins) / 60;

        return hrs + ':' + mins + ':' + secs;
    }

    // TODO: Get similar shows and similar shows on plex server
    return (
        <>
            <div className="">{title}</div>
            <div className="flex flex-wrap overflow-scroll scrollbar-hide">
                <div className="w-1/2">
                    <img src={thumb} className="w-3/4 mx-auto" alt="" />
                </div>
                <div className="w-1/2">
                    Rating: {contentRating}
                    Review Score: {audienceRating}
                    Running Time: {msToTime(duration)}
                    Studio: {studio}
                    Directed By: {director}

                    <div className="">{summary}</div>
                </div>
                {/* <div className="w-full overflow-scroll">
                    <Row {...allMedia[0]} />
                </div> */}
            </div>
        </>
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

export default TitlePage;