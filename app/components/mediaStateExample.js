const media = [
    // Row:
    {
        mediaProvidedBy: 'plex', // or 'netflix or 'chatGPT' or other API service,
        title: 'In your Plex Library',
        rowId: '', // used to keep track of what media is being shown in the page
        // Titles: 
        titles: [
            // Title:
            {
                addedAt: '',
                art: ''
                // All the data that is known about a movie
            }, // More and more titles
        ]
    },
    // Recommended row:
    {
        mediaProvidedBy: 'chatGPT',
        title: 'Recommended for You - ${genre}',
        rowId: '',
        titles: [
            // minimum title data:
            title: '',
            tagline: '',
            year: '',
            // some sort of background picture
        ]
    }
    // More and more row
]

const mediaShown = ['fullOfRowIds',]