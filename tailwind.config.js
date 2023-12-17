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
                plexYellow: '#e6ab01',
                plexYellowHover: '#f4cc53'
            }
        },
    },
    plugins: [],
};
