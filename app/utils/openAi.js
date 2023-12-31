export const recomendMessages = (dataArray) => ([
    {"role": "system", "content": "Given an array of movie or tv show names group them based on similarity, if needed, a group can be a single movie or tv show but try and group them together if possible. If all the movies and tv shows are similar they can be grouped into one single group."},
    {"role": "system", "content": "Then provide 15 recommendations of similar movies and tv shows for each grouping. Give each group a title based on the genre of movies similar to how Netflix categorizes movies and shows." },
    {"role": "system", "content": "If you can not find 15 similar movies or tv shows then please just pick movies at random from the genre you selected." },
    {"role": "system", "content": "Provide data as a json array of objects with the following format: [{category: '...', given_movies: ['movie 1', 'movie 2', ...], suggested_movies: [{'title': title, 'mediaType': 'tv' or 'movie'}, ...]}]"},
    {"role": "system", "content": "Do not provide any text outside of the given json array, do not include any file type identifications, the response needs to only be the array, starting with [ and ending with ]"},
    {"role": "user", "content": JSON.stringify(dataArray)}
])

export const recomendMatchMessages = (dataArray) => ([
    {"role": "system", "content": "You will be given an array that has two arrays inside of it. The first array will have movies and tv shows that I enjoyed. The second array will be a list of movies and tv shows in my personal library."},
    {"role": "system", "content": "Please come up with a category name for the movies and tv shows I enjoyed and then find 30 movies or tv shows from my personal library that most closely match the ones that I enjoyed." },
    {"role": "system", "content": "If you can not come up with any movies or tv shows from my library that are similar please select 30 from my library that would be closest to the category you've come up with." },
    {"role": "system", "content": "Provide data as a single json object with the following format: {category: '...', given_movies: ['movie 1', 'movie 2', ...], suggested_movies: [{'title': title, 'mediaType': 'tv' or 'movie'}, ...]}"},
    {"role": "system", "content": "Do not provide any text outside of the given json object, do not include any file type identifications, the response needs to only be the object, starting with { and ending with }"},
    {"role": "user", "content": JSON.stringify(dataArray)}
])

export const fetchChatGptRecommendations = (openAiToken, titlesArray) => {
    return fetch('https://api.openai.com/v1/chat/completions', {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${openAiToken}`
        },
        body: JSON.stringify({
            "model": "gpt-4-1106-preview",
            "messages": recomendMessages(titlesArray)
        })
    }).then(response => response.json())
    .then(data => {
        const stopReason = data.choices[0].finish_reason;
        const recommendations = data.choices[0].message.content.replace('```json','').replace('```','');
        const jsonRecs = JSON.parse(recommendations.replace('```json','').replace('```',''))
        return {
            jsonRecs,
            stopReason
        }
    });
}

export const fetchChatGptMatches = (openAiToken, titlesArray) => {
    return fetch('https://api.openai.com/v1/chat/completions', {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${openAiToken}`
        },
        body: JSON.stringify({
            "model": "gpt-4-1106-preview",
            "messages": recomendMatchMessages(titlesArray)
        })
    }).then(response => response.json())
    .then(data => {
        const stopReason = data.choices[0].finish_reason;
        const recommendations = data.choices[0].message.content.replace('```json','').replace('```','');
        const jsonMatches = JSON.parse(recommendations.replace('```json','').replace('```',''))
        return {
            jsonMatches,
            stopReason
        }
    });
}
