export const plexDataToJson = (title) => {
    return (
        {
            addedAt: title.$.addedAt,
            art: title.$.art,
            audienceRating: title.$.audienceRating,
            audienceRatingImage: title.$.audienceRatingImage,
            contentRating: title.$.contentRating,
            duration: title.$.duration,
            guid: title.$.guid,
            key: title.$.key,
            lastViewedAt: title.$.lastViewedAt,
            originallyAvailableAt: title.$.originallyAvailableAt,
            primaryExtraKey: title.$.primaryExtraKey,
            rating: title.$.rating,
            ratingImage: title.$.ratingImage,
            ratingKey: title.$.ratingKey,
            studio: title.$.studio,
            summary: title.$.summary,
            tagline: title.$.tagline,
            thumb: title.$.thumb,
            title: title.$.title,
            type: title.$.type,
            updatedAt: title.$.updatedAt,
            viewCount: title.$.viewCount,
            year: title.$.year,
            country: title.Country?.map(country => country.$.tag),
            director: title.Director?.map(director => director.$.tag),
            genre: title.Genre?.map(genre => genre.$.tag),
            media: title.Media?.flatMap(media => [media.$, media.Part[0].$]),
            role: title.Role?.map(role => role.$.tag),
            writer: title.Writer?.map(writer => writer.$.tag)
        }
    )
}

export const getPlexMostWatchlisted = (plexToken) => {
    fetch(`https://discover.provider.plex.tv/hubs/sections/home/top_watchlisted?X-Plex-Token=${plexToken}&X-Plex-Language=en`, {
        method: "GET"
    }).then(response => response.text())
    .then(data => {
        parseString(data, function (err, result) {
            console.log(result);
            return result
        });
    });
}