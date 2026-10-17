/**
 * Capture HLS manifest bodies from Puppeteer response events.
 * Puppeteer 24 removed page.route() — use response.text() with a timeout instead.
 */

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function isManifestUrl(url) {
    return url.includes('.m3u8') || url.includes('.mpd');
}

/** Path after the quality root (/1/high/mono.m3u8 → high/mono.m3u8). */
function qualityPathSuffix(pathname) {
    const match = String(pathname || '').match(/\/\d+\/(.+)$/);
    return match ? match[1] : '';
}

function isValidManifestText(text) {
    return text.includes('#EXTM3U') || text.includes('#EXT-X-');
}

/** @type {WeakMap<import('puppeteer').Page, object>} */
const capturesByPage = new WeakMap();

/**
 * @param {import('puppeteer').HTTPResponse} response
 * @param {number} [timeoutMs]
 */
async function tryReadResponseBody(response, timeoutMs = 8000) {
    const read = async (method) => Promise.race([
        method(),
        new Promise((_, reject) => {
            setTimeout(() => reject(new Error('body read timeout')), timeoutMs);
        }),
    ]);

    try {
        const text = await read(() => response.text());
        if (isValidManifestText(text)) {
            return text;
        }
    } catch {
        // Fall through to buffer.
    }

    try {
        const buffer = await read(() => response.buffer());
        const text = buffer.toString('utf8');
        if (isValidManifestText(text)) {
            return text;
        }
    } catch {
        // Unreadable in Puppeteer — caller may use document fallback.
    }

    return null;
}

/**
 * @param {import('puppeteer').Page} page
 * @param {(msg: string) => void} [log]
 */
export async function attachManifestCapture(page, log = () => {}) {
    const existing = capturesByPage.get(page);
    if (existing) {
        return existing;
    }

    /** @type {Map<string, string>} */
    const bodiesByUrl = new Map();
    /** @type {Set<string>} */
    const loggedUrls = new Set();

    const onResponse = (response) => {
        const url = response.url();
        if (!isManifestUrl(url) || response.status() !== 200) {
            return;
        }

        void (async () => {
            const text = await tryReadResponseBody(response);
            if (text) {
                bodiesByUrl.set(url, text);
                if (!loggedUrls.has(url)) {
                    loggedUrls.add(url);
                    log(`  -> Captured ${url.split('/').pop()} (${text.length} chars)`);
                }
            }
        })();
    };

    page.on('response', onResponse);

    const capture = {
        getBody(url) {
            return bodiesByUrl.get(url) || null;
        },

        getAnyBody() {
            const values = [...bodiesByUrl.values()];
            return values.length > 0 ? values[values.length - 1] : null;
        },

        /**
         * Latest body for a URL. Match exact URL, same pathname, or same
         * quality-root suffix (/N/high/mono.m3u8). Never return a different
         * playlist (e.g. master playlist.m3u8 for a mono.m3u8 request) — that
         * caused nested /high/high/ rewrite loops on Roku.
         */
        getLatestForUrl(preferredUrl) {
            const exact = bodiesByUrl.get(preferredUrl);
            if (exact) {
                return exact;
            }

            let preferredPath = '';
            try {
                preferredPath = new URL(preferredUrl).pathname;
            } catch {
                preferredPath = preferredUrl.split('?')[0] || '';
            }
            if (!preferredPath) {
                return null;
            }

            for (const [url, body] of bodiesByUrl) {
                try {
                    if (new URL(url).pathname === preferredPath) {
                        return body;
                    }
                } catch {
                    // Ignore malformed capture keys.
                }
            }

            const preferredSuffix = qualityPathSuffix(preferredPath);
            if (preferredSuffix) {
                for (const [url, body] of bodiesByUrl) {
                    try {
                        if (qualityPathSuffix(new URL(url).pathname) === preferredSuffix) {
                            return body;
                        }
                    } catch {
                        // Ignore malformed capture keys.
                    }
                }
            }

            return null;
        },

        /** @param {string} url @param {number} [timeoutMs] */
        async waitForBody(url, timeoutMs = 12000) {
            const deadline = Date.now() + timeoutMs;
            while (Date.now() < deadline) {
                const matched = this.getLatestForUrl(url);
                if (matched) {
                    return matched;
                }
                await sleep(150);
            }
            return this.getLatestForUrl(url);
        },

        dispose() {
            page.off('response', onResponse);
            capturesByPage.delete(page);
        },
    };

    capturesByPage.set(page, capture);
    return capture;
}

/**
 * Close ad tabs opened via window.open() when play is clicked.
 * @param {import('puppeteer').Page} page
 * @param {(msg: string) => void} [log]
 */
export function attachAdWindowHandler(page, log = () => {}) {
    page.on('popup', async (popup) => {
        try {
            const url = popup.url() || '(loading)';
            log(`-- Ad window opened (${url}), closing`);
            await popup.close();
        } catch {
            // Popup may already be gone.
        }
    });
}

/**
 * @param {import('puppeteer').Page} page
 */
async function readManifestFromDocument(page) {
    return page.evaluate(() => (
        document.body?.innerText || document.documentElement?.textContent || ''
    ));
}

/**
 * Fetch manifest on a page that already has embed session state.
 * @param {import('puppeteer').Page} page
 * @param {string} url
 * @param {string} referer
 * @param {(msg: string) => void} [log]
 */
export async function fetchManifestOnPage(page, url, referer, log = () => {}) {
    const headers = { Referer: referer };
    try {
        headers.Origin = new URL(referer).origin;
    } catch {
        // Optional
    }
    await page.setExtraHTTPHeaders(headers);

    const capture = await attachManifestCapture(page, log);

    log(`Navigating to manifest: ${url.slice(0, 100)}...`);
    let response;
    try {
        response = await page.goto(url, {
            waitUntil: 'domcontentloaded',
            timeout: 30000,
        });
    } catch (error) {
        throw new Error(`Manifest navigation failed: ${error.message}`);
    }

    const statusCode = response?.status() ?? 0;

    let body = capture.getBody(url);
    if (!body) {
        body = await capture.waitForBody(url, 5000);
    }
    if (!body) {
        body = capture.getAnyBody();
    }
    if (!body) {
        const pageText = await readManifestFromDocument(page);
        if (isValidManifestText(pageText)) {
            body = pageText;
            log(`  -> Read manifest from page document (${body.length} chars)`);
        }
    }

    body = body || '';

    log(`Manifest fetch status ${statusCode}, body ${body.length} chars`);
    if (body.length > 0) {
        log(`Manifest preview: ${body.split('\n').slice(0, 3).join(' | ')}`);
    }

    return {
        statusCode,
        headers: { 'content-type': 'application/vnd.apple.mpegurl' },
        body,
    };
}

/** @deprecated alias */
export const attachManifestRouteCapture = attachManifestCapture;

/**
 * Read the latest manifest the embed player already fetched — no navigation.
 * @param {import('puppeteer').Page} page
 * @param {string} [preferredUrl]
 */
export function getLatestManifestBody(page, preferredUrl = '') {
    const capture = capturesByPage.get(page);
    if (!capture) {
        return null;
    }
    return preferredUrl ? capture.getLatestForUrl(preferredUrl) : capture.getAnyBody();
}

/**
 * Wait for the embed player to produce a manifest body.
 * @param {import('puppeteer').Page} page
 * @param {string} url
 * @param {number} [timeoutMs]
 */
export async function waitForLatestManifestBody(page, url, timeoutMs = 8000) {
    const capture = capturesByPage.get(page);
    if (!capture) {
        return null;
    }
    // Already have manifests but none match this URL → don't stall; caller fetches.
    if (capture.getAnyBody() && !capture.getLatestForUrl(url)) {
        return null;
    }
    await capture.waitForBody(url, timeoutMs);
    return capture.getLatestForUrl(url);
}
