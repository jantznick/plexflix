import { BROWSER_USER_AGENT, buildFetchHeaders } from '../src/proxy-payload.js';

/**
 * Fetch upstream via Node HTTP (fast path when scrape-time replay returned 200).
 * @param {string} url
 * @param {string} referer
 * @param {Record<string, string>} extraHeaders
 * @param {boolean} isText
 * @param {{ minimal?: boolean }} [options] - minimal: UA+Accept+Referer only (no Origin/Sec-Fetch).
 *   TimStreams / TikTok image CDN often 403s when Origin is set.
 */
export async function fetchViaHttp(url, referer, extraHeaders, isText, options = {}) {
    const headers = options.minimal
        ? {
            'User-Agent': BROWSER_USER_AGENT,
            Accept: '*/*',
            ...(referer ? { Referer: referer } : {}),
        }
        : buildFetchHeaders(referer, extraHeaders);
    const response = await fetch(url, { headers, redirect: 'follow' });
    const body = isText
        ? await response.text()
        : Buffer.from(await response.arrayBuffer());

    const responseHeaders = {};
    response.headers.forEach((value, key) => {
        responseHeaders[key] = value;
    });

    return {
        statusCode: response.status,
        headers: responseHeaders,
        body,
    };
}
