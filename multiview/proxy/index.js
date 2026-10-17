const express = require('express');
const http = require('http');
const createHlsProxyMiddleware = require('./node_modules/@warren-bank/hls-proxy/hls-proxy/proxy');

const app = express();
const port = process.env.PORT || 8787;
const proxyHost = process.env.PROXY_HOST || '192.168.1.50:8787';

const refererUrl = "https://embedsports.top/";
const origin = new URL(refererUrl).origin;

console.log(`Starting proxy with hardcoded referer: ${refererUrl}`);

const middleware = createHlsProxyMiddleware({
    'host': proxyHost,
    'req-headers': {
        'Referer': refererUrl,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/117.0'
    },
    // Add this option to ignore SSL certificate errors from the upstream server.
    'req_options': {
        'rejectUnauthorized': false
    },
    // Increase debug level for maximum verbosity to inspect manifest rewriting.
    'debug_level': 3,
});

app.use('/proxy', middleware.request);

http.createServer(app).listen(port, () => {
    console.log(`HLS Proxy server listening at http://localhost:${port}`);
    console.log(`Rewriting segment URLs to use host: ${proxyHost}`);
});