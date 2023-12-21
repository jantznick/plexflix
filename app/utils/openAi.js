export const recomendMessages = (dataArray) => ([
        {"role": "system", "content": "Given an array of movie names group them based on similarity, if needed, a group can be a single movie but try and group them together if possible. If all the movies are similar they can be grouped into one single group."},
        {"role": "system", "content": "Then provide 5 recommendations of similar movies for each grouping. Give each group a title based on the genre of movies similar to how Netflix categorizes movies and shows." },
        {"role": "system", "content": "Provide data as a json array of objects with the following format: [{category: '...', given_movies: ['movie 1', 'movie 2', ...], suggested_movies: ['movie 1', 'movie 2', ...]}]"},
        {"role": "system", "content": "Do not provide any text outside of the given json array, do not include any file type identifications, the response needs to only be the array, starting with [ and ending with ]"},
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
        return data
    });
}
