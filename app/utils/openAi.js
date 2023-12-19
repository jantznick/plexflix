export const recomendMessages = (dataArray) => ([
        {"role": "system", "content": "Given an array of movie names group them based on similarity, if needed, a group can be a single movie but try and group them together if possible. If all the movies are similar they can be grouped into one single group."},
        {"role": "system", "content": "Then provide 5 recommendations of similar movies for each grouping. Give each group a title based on the genre of movies similar to how Netflix categorizes movies and shows." },
        {"role": "system", "content": "Provide data as a json array of objects with the following format: [{category: '...', given_movies: ['movie 1', 'movie 2', ...], suggested_movies: ['movie 1', 'movie 2', ...]}]"},
        {"role": "system", "content": "Do not provide any text outside of the given json object"},
        {"role": "user", "content": JSON.stringify(dataArray)}
    ])
