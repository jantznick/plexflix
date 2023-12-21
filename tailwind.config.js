module.exports = {
    content: ['./**/*.html', './app/**/*.js'],
    theme: {
        screens: {
            sm: '480px',
            md: '768px',
            lg: '976px',
            xl: '1440px'
        },
        extend: {
            colors: {
                plexYellow: 'rgba(230,171,1,1)',
                plexYellowTransparent: 'rgba(230,171,1,.75)',
                plexYellowHover: 'rgba(244,204,83,1)'
            }
        },
    },
    plugins: [],
};
