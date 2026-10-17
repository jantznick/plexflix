import { resolveStreamFromEmbed } from '../src/embed-resolver.js';
import {
    clearAllEmbedPages,
    clearEmbedPage,
    setEmbedPage,
} from './embed-pages.js';
import { getBrowser } from './browser-fetch.js';

/** @type {Map<string, object>} */
const resolvedByEmbed = new Map();
/** @type {Map<string, Promise<object>>} */
const resolveInFlight = new Map();

export function getCachedStream(embedUrl) {
    return resolvedByEmbed.get(embedUrl) || null;
}

export { getEmbedPage } from './embed-pages.js';

export function markCapturedManifestServed(embedUrl) {
    const entry = resolvedByEmbed.get(embedUrl);
    if (entry) {
        entry.servedCapturedManifest = true;
    }
}

export function clearResolvedStream(embedUrl) {
    clearEmbedPage(embedUrl);
    resolvedByEmbed.delete(embedUrl);
}

export function clearAllResolvedStreams() {
    clearAllEmbedPages();
    resolvedByEmbed.clear();
}

/**
 * Resolve a fresh m3u8 from the embed page (once per embed until cache cleared).
 * Keeps the embed page open so manifest/segment fetches reuse the player session.
 * @param {string} embedUrl
 * @param {{ force?: boolean }} [options]
 */
export async function getResolvedStream(embedUrl, { force = false } = {}) {
    if (!embedUrl) {
        throw new Error('Embed URL (e) is required in the proxy payload — re-scrape the feed');
    }

    if (!force && resolvedByEmbed.has(embedUrl)) {
        return resolvedByEmbed.get(embedUrl);
    }

    if (resolveInFlight.has(embedUrl)) {
        return resolveInFlight.get(embedUrl);
    }

    const task = (async () => {
        if (force) {
            clearResolvedStream(embedUrl);
        }

        console.log(`[stream-session] Opening embed in Puppeteer: ${embedUrl}`);
        const browser = await getBrowser();
        const result = await resolveStreamFromEmbed(browser, embedUrl, {
            sourceName: 'proxy',
            verbose: true,
            checkNodeReplay: true,
            captureManifestBody: true,
            keepPageOpen: true,
        });

        if (!result?.streamUrl) {
            throw new Error(`Could not resolve m3u8 from embed: ${embedUrl}`);
        }

        if (result.embedPage) {
            setEmbedPage(embedUrl, result.embedPage);
        }

        const entry = {
            ...result,
            servedCapturedManifest: false,
        };
        delete entry.embedPage;

        resolvedByEmbed.set(embedUrl, entry);
        console.log(`[stream-session] Fresh manifest: ${result.streamUrl}`);
        console.log(`[stream-session] Referer: ${result.referer}`);
        console.log(`[stream-session] Direct HTTP path (d): ${result.directFetchOk ? '1' : '0'}`);
        if (result.manifestBody) {
            console.log('[stream-session] Manifest body cached from embed resolve');
        } else {
            console.log('[stream-session] Embed page kept open for manifest fetch');
        }
        return entry;
    })();

    resolveInFlight.set(embedUrl, task);
    try {
        return await task;
    } finally {
        resolveInFlight.delete(embedUrl);
    }
}
