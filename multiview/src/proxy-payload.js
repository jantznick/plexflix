const DEFAULT_REFERER = 'https://embedsports.top/';
const BROWSER_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36';

export { BROWSER_USER_AGENT };

const PASSTHROUGH_HEADER_NAMES = [
    'accept',
    'accept-language',
    'cache-control',
    'pragma',
    'origin',
    'cookie',
    'sec-fetch-site',
    'sec-fetch-mode',
    'sec-fetch-dest',
    'sec-ch-ua',
    'sec-ch-ua-mobile',
    'sec-ch-ua-platform',
];

/** Use the referer the browser actually sent; fall back to the embed page origin. */
export function pickReferer(embedUrl, capturedReferer) {
    const captured = capturedReferer?.trim();
    if (captured) {
        return captured;
    }

    try {
        return `${new URL(embedUrl).origin}/`;
    } catch {
        return DEFAULT_REFERER;
    }
}

export function extractPassthroughHeaders(requestHeaders = {}) {
    const passthrough = {};
    const normalized = Object.fromEntries(
        Object.entries(requestHeaders).map(([key, value]) => [key.toLowerCase(), value])
    );

    for (const name of PASSTHROUGH_HEADER_NAMES) {
        const value = normalized[name];
        if (value) {
            passthrough[name] = value;
        }
    }
    return passthrough;
}

/** @returns {string} base64 JSON payload for /proxy/:payload routes */
export function encodeProxyPayload(url, referer, extraHeaders = {}, embedUrl = null, directOk = false) {
    const payload = {
        u: url,
        r: referer || DEFAULT_REFERER,
    };
    if (embedUrl) {
        payload.e = embedUrl;
    }
    if (directOk) {
        payload.d = 1;
    }
    if (extraHeaders && Object.keys(extraHeaders).length > 0) {
        payload.h = extraHeaders;
    }
    return Buffer.from(JSON.stringify(payload)).toString('base64');
}

/** @returns {{ url: string, referer: string, extraHeaders: Record<string, string>, embedUrl: string | null, directOk: boolean }} */
export function decodeProxyPayload(b64Payload) {
    const raw = Buffer.from(b64Payload, 'base64').toString('utf8');

    if (raw.startsWith('{')) {
        try {
            const parsed = JSON.parse(raw);
            return {
                url: parsed.u,
                referer: parsed.r || DEFAULT_REFERER,
                extraHeaders: parsed.h || {},
                embedUrl: parsed.e || null,
                directOk: Boolean(parsed.d),
            };
        } catch {
            // Fall through to legacy plain-URL payload.
        }
    }

    return { url: raw, referer: DEFAULT_REFERER, extraHeaders: {}, embedUrl: null, directOk: false };
}

export function buildProxyUrl(streamUrl, referer, proxyServer, extraHeaders = {}, embedUrl = null, directOk = false) {
    const base = proxyServer.replace(/\/$/, '');
    return `${base}/proxy/${encodeProxyPayload(streamUrl, referer, extraHeaders, embedUrl, directOk)}`;
}

export function buildFetchHeaders(referer, extraHeaders = {}) {
    const normalizedExtra = Object.fromEntries(
        Object.entries(extraHeaders).map(([key, value]) => [key.toLowerCase(), value])
    );

    const headers = {
        'User-Agent': BROWSER_USER_AGENT,
        Accept: '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cache-Control': 'no-cache',
        Pragma: 'no-cache',
        Referer: referer,
        ...normalizedExtra,
    };

    if (!headers.origin) {
        try {
            headers.Origin = new URL(referer).origin;
        } catch {
            // Referer may be missing or malformed; Origin is optional.
        }
    }

    if (!headers['sec-fetch-site']) {
        headers['Sec-Fetch-Site'] = 'cross-site';
        headers['Sec-Fetch-Mode'] = 'cors';
        headers['Sec-Fetch-Dest'] = 'empty';
    }

    if (!headers['sec-ch-ua']) {
        headers['sec-ch-ua'] = '"Chromium";v="148", "Google Chrome";v="148", "Not/A)Brand";v="99"';
        headers['sec-ch-ua-mobile'] = '?0';
        headers['sec-ch-ua-platform'] = '"macOS"';
    }

    return headers;
}

export function scoreManifestUrl(url) {
    if (url.includes('/high/mono.m3u8')) return 100;
    if (url.includes('/mono.m3u8')) return 90;
    if (url.includes('playlist.m3u8')) return 50;
    if (url.includes('.mpd')) return 40;
    if (url.includes('.m3u8')) return 30;
    return 0;
}

/** True if a bare m3u8 line should be rewritten / fetched as stream media. */
export function isHlsMediaUri(uri) {
    const trimmed = uri.trim();
    if (!trimmed || trimmed.startsWith('#')) {
        return false;
    }
    if (trimmed.includes('.m3u8')) {
        return true;
    }
    if (/\.(ts|m4s|mp4|aac|vtt)(\?|#|$)/i.test(trimmed)) {
        return true;
    }
    if (trimmed.includes('strmd.st')) {
        return true;
    }
    // GOAT-processed strmd playlists use bare third-party HTTPS URLs as segment lines.
    if (/^https?:\/\//i.test(trimmed)) {
        return true;
    }
    // Relative segment paths (e.g. segment012.ts)
    return trimmed.length > 0 && !trimmed.includes(' ');
}
