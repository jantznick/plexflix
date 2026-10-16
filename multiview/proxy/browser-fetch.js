import {
    fetchManifestOnPage,
    getLatestManifestBody,
    waitForLatestManifestBody,
} from '../src/manifest-capture.js';
import { launchBrowser as launchStealthBrowser, describePuppeteerMode } from '../src/puppeteer-config.js';
import { BROWSER_USER_AGENT } from '../src/proxy-payload.js';
import { isBrowserConnected } from '../src/puppeteer-utils.js';
import { getEmbedPage } from './embed-pages.js';

async function clearStreamCache() {
    const { clearAllResolvedStreams } = await import('./stream-session.js');
    clearAllResolvedStreams();
}

const IDLE_TIMEOUT_MS = Number.parseInt(process.env.PROXY_BROWSER_IDLE_MS || '', 10) || 10 * 60 * 1000;
const NAV_TIMEOUT_MS = Number.parseInt(process.env.PROXY_NAV_TIMEOUT_MS || '', 10) || 30000;
const PAGE_POOL_SIZE = Number.parseInt(process.env.PROXY_PAGE_POOL_SIZE || '', 10) || 1;
const debug = process.env.PROXY_DEBUG === 'true';

/** @type {import('puppeteer').Browser | null} */
let browser = null;
/** @type {Promise<import('puppeteer').Browser> | null} */
let browserLaunchPromise = null;
/** @type {ReturnType<typeof setTimeout> | null} */
let idleTimer = null;

/** @type {Map<string, BrowserSession>} */
const sessions = new Map();

function logStep(message) {
    console.log(`[browser-fetch] ${message}`);
}

function logDebug(message) {
    if (debug) {
        console.log(`[browser-fetch] ${message}`);
    }
}

function parseCookieHeader(cookieHeader, baseUrl) {
    if (!cookieHeader?.trim()) {
        return [];
    }

    let domain;
    try {
        domain = new URL(baseUrl).hostname;
    } catch {
        return [];
    }

    return cookieHeader.split(';').map((chunk) => {
        const trimmed = chunk.trim();
        const eq = trimmed.indexOf('=');
        if (eq <= 0) {
            return null;
        }
        return {
            name: trimmed.slice(0, eq),
            value: trimmed.slice(eq + 1),
            domain,
            path: '/',
        };
    }).filter(Boolean);
}

async function applyRequestHeaders(page, referer) {
    const headers = { Referer: referer };
    try {
        headers.Origin = new URL(referer).origin;
    } catch {
        // Optional
    }
    await page.setExtraHTTPHeaders(headers);
}

/** @type {Map<string, Promise<void>>} */
const embedSegmentLocks = new Map();

/**
 * Serialize segment fetches that share a page so we don't stomp concurrent evaluate/CDP calls.
 * @template T
 * @param {string} key
 * @param {() => Promise<T>} fn
 * @returns {Promise<T>}
 */
async function withPageLock(key, fn) {
    const previous = embedSegmentLocks.get(key) || Promise.resolve();
    let release;
    const gate = new Promise((resolve) => {
        release = resolve;
    });
    const chain = previous.catch(() => {}).then(() => gate);
    embedSegmentLocks.set(key, chain);
    await previous.catch(() => {});
    try {
        return await fn();
    } finally {
        release();
        if (embedSegmentLocks.get(key) === chain) {
            embedSegmentLocks.delete(key);
        }
    }
}

/**
 * Fetch a segment via in-page fetch() on an embed-origin page (real cookies + Origin).
 * page.goto(.ts) aborts; blank tabs lack the embed Origin and fail CORS/auth.
 * @param {import('puppeteer').Page} page
 * @param {string} url
 */
async function fetchSegmentInPage(page, url) {
    logStep(`In-page segment fetch: ${url.slice(0, 100)}...`);

    const result = await page.evaluate(async (segmentUrl) => {
        try {
            const response = await fetch(segmentUrl, {
                credentials: 'include',
                cache: 'no-store',
                redirect: 'follow',
            });
            if (!response.ok) {
                return { ok: false, status: response.status, error: `HTTP ${response.status}` };
            }
            const buffer = await response.arrayBuffer();
            const blob = new Blob([buffer]);
            const dataUrl = await new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => resolve(String(reader.result || ''));
                reader.onerror = () => reject(reader.error || new Error('FileReader failed'));
                reader.readAsDataURL(blob);
            });
            const comma = dataUrl.indexOf(',');
            return {
                ok: true,
                status: response.status,
                contentType: response.headers.get('content-type') || 'video/MP2T',
                base64: comma >= 0 ? dataUrl.slice(comma + 1) : '',
            };
        } catch (error) {
            return { ok: false, status: 0, error: error?.message || String(error) };
        }
    }, url);

    if (!result?.ok) {
        throw new Error(result?.error || 'in-page segment fetch failed');
    }

    const body = Buffer.from(result.base64, 'base64');
    logStep(`In-page segment fetch OK (${body.length} bytes)`);
    return {
        statusCode: result.status,
        headers: { 'content-type': result.contentType },
        body,
    };
}

/**
 * CDP fallback when page.evaluate(fetch) is CORS-blocked but the browser can still load the URL.
 * @param {import('puppeteer').Page} page
 * @param {string} url
 */
async function fetchSegmentViaCdp(page, url) {
    logStep(`CDP segment fetch: ${url.slice(0, 100)}...`);
    const client = await page.createCDPSession();

    try {
        const { frameTree } = await client.send('Page.getFrameTree');
        const frameId = frameTree?.frame?.id;
        if (!frameId) {
            throw new Error('CDP frame id missing');
        }

        const { resource } = await client.send('Network.loadNetworkResource', {
            frameId,
            url,
            options: {
                disableCache: true,
                includeCredentials: true,
            },
        });

        if (!resource?.success) {
            throw new Error(resource?.netErrorName || resource?.netError || 'CDP loadNetworkResource failed');
        }
        if (resource.httpStatusCode && resource.httpStatusCode >= 400) {
            throw new Error(`CDP HTTP ${resource.httpStatusCode}`);
        }
        if (!resource.stream) {
            throw new Error('CDP resource missing stream handle');
        }

        const chunks = [];
        for (;;) {
            const read = await client.send('IO.read', {
                handle: resource.stream,
                size: 1024 * 1024,
            });
            if (read.data) {
                chunks.push(Buffer.from(read.data, read.base64Encoded ? 'base64' : 'utf8'));
            }
            if (read.eof) {
                break;
            }
        }
        await client.send('IO.close', { handle: resource.stream }).catch(() => {});

        const body = Buffer.concat(chunks);
        logStep(`CDP segment fetch OK (${body.length} bytes)`);
        return {
            statusCode: resource.httpStatusCode || 200,
            headers: { 'content-type': 'video/MP2T' },
            body,
        };
    } finally {
        await client.detach().catch(() => {});
    }
}

/**
 * Prefer in-page fetch on an embed-origin tab; fall back to CDP.
 * @param {import('puppeteer').Page} page
 * @param {string} url
 * @param {string} [lockKey]
 */
async function fetchSegmentFromBrowserPage(page, url, lockKey = 'page') {
    return withPageLock(lockKey, async () => {
        try {
            return await fetchSegmentInPage(page, url);
        } catch (inPageError) {
            logStep(`In-page segment fetch failed (${inPageError.message}); trying CDP`);
            return fetchSegmentViaCdp(page, url);
        }
    });
}

/**
 * Manifests: CDP capture via page navigation (in-page fetch blocked by CORS on strmd).
 * Segments: in-page fetch / CDP on an embed-origin page — never page.goto(.ts).
 */
async function fetchOnPage(page, url, referer, isText) {
    if (isText) {
        return fetchManifestOnPage(page, url, referer, logStep);
    }

    return fetchSegmentFromBrowserPage(page, url, `session:${page.url()}`);
}

class BrowserSession {
    /** @param {import('puppeteer').Page[]} pages */
    constructor(pages, embedUrl, referer) {
        this.pages = pages;
        this.embedUrl = embedUrl;
        this.referer = referer;
        this.lastUsed = Date.now();
        this.nextPage = 0;
        /** @type {boolean[]} */
        this.busy = pages.map(() => false);
    }

    touch() {
        this.lastUsed = Date.now();
        scheduleIdleCleanup();
    }

    async acquirePageIndex() {
        while (true) {
            for (let i = 0; i < this.pages.length; i++) {
                if (!this.busy[i] && !this.pages[i].isClosed()) {
                    this.busy[i] = true;
                    return i;
                }
            }
            await new Promise((resolve) => setTimeout(resolve, 25));
        }
    }

    releasePageIndex(index) {
        this.busy[index] = false;
    }

    /**
     * @param {string} url
     * @param {boolean} isText
     */
    async fetch(url, isText) {
        this.touch();
        const pageIndex = await this.acquirePageIndex();
        const page = this.pages[pageIndex];

        try {
            if (page.isClosed()) {
                throw new Error('Browser session page was closed');
            }

            logStep(`Fetching ${isText ? 'manifest' : 'segment'}: ${url.slice(0, 100)}...`);
            const result = await fetchOnPage(page, url, this.referer, isText);
            logStep(`Upstream status ${result.statusCode} for ${new URL(url).pathname.split('/').slice(-2).join('/')}`);
            return result;
        } finally {
            this.releasePageIndex(pageIndex);
        }
    }

    async close() {
        await Promise.all(this.pages.map((page) => {
            if (!page.isClosed()) {
                return page.close().catch(() => {});
            }
            return undefined;
        }));
    }
}

async function launchBrowser() {
    const mode = describePuppeteerMode();
    logStep(`Launching Chromium (${mode})...`);
    browserLaunchPromise = launchStealthBrowser();

    browser = await browserLaunchPromise;
    browser.on('disconnected', () => {
        browser = null;
        browserLaunchPromise = null;
        sessions.clear();
        void clearStreamCache();
        logStep('Browser disconnected');
    });

    logStep('Chromium ready');
    return browser;
}

async function getBrowser() {
    if (isBrowserConnected(browser)) {
        return browser;
    }

    if (!browserLaunchPromise) {
        return launchBrowser();
    }

    return browserLaunchPromise;
}

export { getBrowser };

function sessionKey(embedUrl, referer) {
    return embedUrl || referer || 'default';
}

async function warmupPage(page, embedUrl, referer) {
    const warmupUrl = embedUrl || referer;
    if (!warmupUrl) {
        return;
    }

    await page.goto(warmupUrl, {
        waitUntil: 'domcontentloaded',
        timeout: NAV_TIMEOUT_MS,
    });
}

async function createSessionPages(activeBrowser, embedUrl, referer, extraHeaders = {}) {
    const cookieBase = embedUrl || referer;
    const cookies = parseCookieHeader(extraHeaders.cookie, cookieBase);
    const pages = [];
    const warmupUrl = embedUrl || referer;

    for (let i = 0; i < PAGE_POOL_SIZE; i++) {
        const page = await activeBrowser.newPage();
        await page.setUserAgent(BROWSER_USER_AGENT);
        await page.setCacheEnabled(false);

        if (cookies.length > 0) {
            await page.setCookie(...cookies);
        }

        // Must load embed origin so in-page segment fetch() sends the right Origin.
        if (warmupUrl) {
            await warmupPage(page, embedUrl, referer);
        }

        pages.push(page);
    }

    if (warmupUrl) {
        logStep(`Warmed ${pages.length} session page(s) on embed origin for segment fetch`);
    } else if (cookies.length > 0) {
        logStep(`Applied ${cookies.length} cookie(s) for segment fetch (no embed URL to warm)`);
    }

    return pages;
}

/**
 * @param {string} embedUrl
 * @param {string} referer
 * @param {Record<string, string>} extraHeaders
 * @returns {Promise<BrowserSession>}
 */
async function getSession(embedUrl, referer, extraHeaders = {}) {
    const key = sessionKey(embedUrl, referer);
    const existing = sessions.get(key);

    if (existing?.pages?.[0] && !existing.pages[0].isClosed()) {
        existing.touch();
        logDebug(`Reusing session ${key}`);
        return existing;
    }

    const activeBrowser = await getBrowser();
    const pages = await createSessionPages(activeBrowser, embedUrl, referer, extraHeaders);
    const session = new BrowserSession(pages, embedUrl, referer);
    sessions.set(key, session);
    scheduleIdleCleanup();
    return session;
}

function scheduleIdleCleanup() {
    if (idleTimer) {
        clearTimeout(idleTimer);
    }

    idleTimer = setTimeout(() => {
        void closeIdleSessions();
    }, IDLE_TIMEOUT_MS);
}

async function closeIdleSessions() {
    const now = Date.now();
    const closeTasks = [];

    for (const [key, session] of sessions.entries()) {
        if (now - session.lastUsed >= IDLE_TIMEOUT_MS) {
            closeTasks.push((async () => {
                await session.close();
                sessions.delete(key);
            })());
        }
    }

    await Promise.all(closeTasks);

    if (sessions.size === 0 && isBrowserConnected(browser)) {
        await browser.close().catch(() => {});
        browser = null;
        browserLaunchPromise = null;
        void clearStreamCache();
        logStep('Closed idle browser');
    } else if (sessions.size > 0) {
        scheduleIdleCleanup();
    }
}

/**
 * Segments are plain CDN URLs (tiktokcdn, strmd .ts, etc.). Fetch the bytes
 * directly with the embed referer — no browser tab needed.
 */
async function tryDirectSegmentFetch(url, referer, extraHeaders = {}) {
    const headers = { 'User-Agent': BROWSER_USER_AGENT };
    if (referer) {
        headers.Referer = referer;
        try {
            headers.Origin = new URL(referer).origin;
        } catch {
            // Optional
        }
    }
    if (extraHeaders.cookie) {
        headers.Cookie = extraHeaders.cookie;
    }

    try {
        const response = await fetch(url, {
            headers,
            redirect: 'follow',
            signal: AbortSignal.timeout(20000),
        });
        if (!response.ok) {
            logStep(`Direct segment fetch HTTP ${response.status}`);
            return null;
        }
        const body = Buffer.from(await response.arrayBuffer());
        logStep(`Direct segment fetch OK (${body.length} bytes)`);
        return {
            statusCode: response.status,
            headers: { 'content-type': response.headers.get('content-type') || 'video/MP2T' },
            body,
        };
    } catch (error) {
        logStep(`Direct segment fetch failed: ${error.message}`);
        return null;
    }
}

export async function fetchViaBrowser(url, { embedUrl, referer, extraHeaders = {} }, isText) {
    const embedPage = embedUrl ? getEmbedPage(embedUrl) : null;
    const embedAlive = embedPage && !embedPage.isClosed();

    if (isText && embedAlive) {
        let body = getLatestManifestBody(embedPage, url);
        if (!body) {
            body = await waitForLatestManifestBody(embedPage, url, 8000);
        }
        if (body) {
            logStep(`Serving live manifest from embed player (${body.length} chars)`);
            return {
                statusCode: 200,
                headers: { 'content-type': 'application/vnd.apple.mpegurl' },
                body,
            };
        }
        logStep('No live manifest on embed page yet; falling back to navigation');
        return fetchManifestOnPage(embedPage, url, referer, logStep);
    }

    if (!isText) {
        const direct = await tryDirectSegmentFetch(url, referer, extraHeaders);
        if (direct) {
            return direct;
        }
        logStep('Direct segment fetch failed; trying embed-page browser fetch');

        // Prefer the already-open embed player tab (correct Origin + cookies).
        if (embedAlive) {
            try {
                return await fetchSegmentFromBrowserPage(embedPage, url, `embed:${embedUrl}`);
            } catch (embedError) {
                logStep(`Embed-page segment fetch failed (${embedError.message}); falling back to session tab`);
            }
        }
    }

    const session = await getSession(embedUrl, referer, extraHeaders);
    return session.fetch(url, isText);
}

export async function resetBrowserSessions() {
    for (const session of sessions.values()) {
        await session.close();
    }
    sessions.clear();

    if (isBrowserConnected(browser)) {
        await browser.close().catch(() => {});
    }

    browser = null;
    browserLaunchPromise = null;
}

export async function shutdownBrowserFetch() {
    if (idleTimer) {
        clearTimeout(idleTimer);
        idleTimer = null;
    }
    await resetBrowserSessions();
}

for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => {
        void shutdownBrowserFetch().finally(() => process.exit(0));
    });
}
