import express from 'express';
import fs from 'fs';
import http from 'http';
import path from 'path';
import {
    decodeProxyPayload,
    encodeProxyPayload,
    isHlsMediaUri,
} from '../src/proxy-payload.js';
import { fetchViaBrowser } from './browser-fetch.js';
import { fetchViaHttp } from './http-fetch.js';
import {
    clearResolvedStream,
    getCachedStream,
    getResolvedStream,
} from './stream-session.js';
import {
    ensureRemuxSession,
    getRemuxRoot,
    shutdownAudioRemux,
    touchRemuxSession,
} from './audio-remux.js';

const app = express();
const port = process.env.PORT || 8787;
const proxyHost = process.env.PROXY_HOST || '192.168.1.50:8787';
const debug = process.env.PROXY_DEBUG === 'true';

const PROXY_VERSION = 'embed-first-v25-remux-loopback';

function isLoopbackClient(req) {
    const ip = String(req.ip || req.socket?.remoteAddress || '');
    return ip === '127.0.0.1' || ip === '::1' || ip.endsWith('127.0.0.1');
}

/** Roku uses PROXY_HOST; ffmpeg remux inside the container must use 127.0.0.1. */
function rewriteProxyHost(req) {
    if (isLoopbackClient(req)) {
        return `127.0.0.1:${port}`;
    }
    return proxyHost;
}

/** Path after the quality root (/1/high/mono.m3u8 → high/mono.m3u8). */
function qualityPathSuffix(pathname) {
    const match = String(pathname || '').match(/\/\d+\/(.+)$/);
    return match ? match[1] : '';
}

/**
 * Map a stale feed/CDN URL onto the live token/host from embed resolve.
 * fresh master: .../TOKEN/1/playlist.m3u8
 * request:      .../OLD/1/high/mono.m3u8
 * result:       .../TOKEN/1/high/mono.m3u8
 */
function rebaseOntoFreshMaster(requestUrl, freshMasterUrl) {
    try {
        const req = new URL(requestUrl);
        const fresh = new URL(freshMasterUrl);
        const suffix = qualityPathSuffix(req.pathname);
        const freshRoot = fresh.pathname.match(/^(.*\/\d+)\//);
        if (!suffix || !freshRoot) {
            return null;
        }
        // Entry / master itself → keep the resolved master URL.
        if (suffix === 'playlist.m3u8' || suffix.endsWith('/playlist.m3u8')) {
            return fresh.href;
        }
        fresh.pathname = `${freshRoot[1]}/${suffix}`;
        fresh.search = '';
        return fresh.href;
    } catch {
        return null;
    }
}

function masterVariantSuffixes(masterBody) {
    const suffixes = new Set();
    for (const line of String(masterBody || '').split('\n')) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) {
            continue;
        }
        suffixes.add(trimmed.replace(/^\.\//, ''));
    }
    return suffixes;
}

// GOAT disguises each MPEG-TS segment as a tiny PNG so it can live on TikTok's
// image CDN. The real TS payload starts right after the PNG's IEND chunk. Strip
// the PNG wrapper so players (VLC, Roku) get clean MPEG-TS they can decode.
const PNG_SIGNATURE = Buffer.from('89504e470d0a1a0a', 'hex');
const RIFF_MAGIC = Buffer.from('RIFF');
const WEBP_MAGIC = Buffer.from('WEBP');
const MPEG_TS_PACKET_SIZE = 188;
const MPEG_TS_SYNC = 0x47;

function unwrapGoatSegment(body) {
    if (!Buffer.isBuffer(body) || body.length < 8) {
        return body;
    }
    if (!body.subarray(0, 8).equals(PNG_SIGNATURE)) {
        return body;
    }
    const iendIndex = body.indexOf('IEND');
    if (iendIndex === -1) {
        return body;
    }
    const tsStart = iendIndex + 4 + 4; // "IEND" (4) + CRC (4)
    const payload = body.subarray(tsStart);
    console.log(`  - Unwrapped GOAT PNG segment: ${body.length} -> ${payload.length} bytes`);
    return payload;
}

/**
 * TimStreams / junksonus segments arrive as a fake WebP (RIFF…WEBP) whose payload
 * is raw MPEG-TS. Find a sustained 0x47 sync run (188-byte packets) and return it.
 * Does not modify PNG GOAT handling — call after unwrapGoatSegment when unchanged.
 */
function unwrapWebpTsSegment(body) {
    if (!Buffer.isBuffer(body) || body.length < 16) {
        return body;
    }
    if (!body.subarray(0, 4).equals(RIFF_MAGIC) || !body.subarray(8, 12).equals(WEBP_MAGIC)) {
        return body;
    }

    const minPackets = 3;
    const searchLimit = Math.min(body.length, 64 * 1024);
    for (let i = 0; i < searchLimit; i++) {
        if (body[i] !== MPEG_TS_SYNC) {
            continue;
        }
        let packets = 0;
        let offset = i;
        while (
            offset + MPEG_TS_PACKET_SIZE <= body.length &&
            body[offset] === MPEG_TS_SYNC
        ) {
            packets++;
            offset += MPEG_TS_PACKET_SIZE;
        }
        if (packets >= minPackets) {
            const payload = body.subarray(i, i + packets * MPEG_TS_PACKET_SIZE);
            console.log(
                `  - Unwrapped WebP-TS segment: ${body.length} -> ${payload.length} bytes ` +
                    `(offset ${i}, ${packets} packets)`
            );
            return payload;
        }
    }

    console.log('  - WebP segment had no sustained MPEG-TS sync run; passing through');
    return body;
}

/** PNG GOAT first (Streamed), then WebP-TS (TimStreams); otherwise passthrough. */
function unwrapDisguisedSegment(body) {
    const afterPng = unwrapGoatSegment(body);
    if (afterPng !== body) {
        return afterPng;
    }
    return unwrapWebpTsSegment(body);
}

/**
 * Express 5 named wildcard (`*b64Payload`) may return a string or path-segment array.
 * Standard base64 payloads can contain `/`, so re-join segments.
 */
function extractB64Payload(param) {
    if (Array.isArray(param)) {
        return param.join('/');
    }
    if (typeof param === 'string') {
        return param.replace(/^\//, '');
    }
    return '';
}

function previewBody(body, maxLines = 6) {
    const text = typeof body === 'string' ? body : body.toString('utf8');
    const lines = text.split('\n').filter((line) => line.trim().length > 0).slice(0, maxLines);
    return { text, lines, totalChars: text.length, totalLines: text.split('\n').length };
}

function logManifestPreview(label, body) {
    const { lines, totalChars, totalLines } = previewBody(body);
    console.log(`  - ${label}: ${totalChars} chars, ${totalLines} lines`);
    for (const line of lines) {
        console.log(`      ${line}`);
    }
    if (totalLines > lines.length) {
        console.log(`      ... (${totalLines - lines.length} more lines)`);
    }
}

console.log(`Starting ADVANCED HLS proxy (${PROXY_VERSION})...`);
console.log(`  - Chromium mode: ${process.env.PROXY_HEADLESS === 'true' ? 'headless' : 'visible (set PROXY_HEADLESS=true for headless)'}`);
console.log(`  - Rewriting segment URLs to host: ${proxyHost}`);
console.log('  - /proxy d=1 (TimStreams): HTTP first, Chromium fallback for segments; WebP-TS unwrap');
console.log('  - /proxy otherwise: Puppeteer embed-first (Streamed)');
console.log('  - /remux/{payload}: ffmpeg video-copy + AAC-LC (Roku HE-AAC workaround)');

app.get('/', (req, res) => {
    res.send('Proxy server is running (embed-first stream resolve)');
});

// Remux live HLS (HE-AAC → AAC-LC). Same payload as /proxy/{b64}.
// Serve the playlist inline (absolute segment URLs) — Roku HLS is flaky on 302.
app.get('/remux/*b64Payload', async (req, res) => {
    const b64Payload = extractB64Payload(req.params.b64Payload);
    if (!b64Payload) {
        res.status(400).send('Missing remux payload');
        return;
    }
    console.log(`---\n[${new Date().toISOString()}] Remux request`);
    console.log(`  - Payload length: ${b64Payload.length}`);
    try {
        const session = await ensureRemuxSession(b64Payload);
        const playlistPath = path.join(session.dir, 'index.m3u8');
        const playlist = fs.readFileSync(playlistPath, 'utf8');
        const base = `http://${proxyHost}/remux-live/${session.id}/`;
        const rewritten = playlist.split('\n').map((line) => {
            const trimmed = line.trim();
            if (trimmed.length > 0 && !trimmed.startsWith('#') && !/^https?:\/\//i.test(trimmed)) {
                return base + trimmed.replace(/^\.\//, '');
            }
            return line;
        }).join('\n');
        console.log(`  - Serving remux playlist (${session.id})`);
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        res.send(rewritten);
    } catch (error) {
        console.error(`  - Remux failed: ${error.message}`);
        if (!res.headersSent) {
            res.status(502).send(`Remux failed: ${error.message}`);
        }
    }
});

app.use('/remux-live', (req, res, next) => {
    const id = String(req.path || '').split('/').filter(Boolean)[0] || '';
    if (id) {
        touchRemuxSession(id);
    }
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    next();
}, express.static(getRemuxRoot()));

function isManifestUrl(url) {
    return url.endsWith('.m3u8') || url.includes('.m3u8?');
}

function buildRewrittenPayload(url, referer, extraHeaders, embedUrl, directOk) {
    return encodeProxyPayload(url, referer, extraHeaders, embedUrl, directOk);
}

async function fetchUpstream(streamUrl, { embedUrl, referer, extraHeaders, directOk }, isManifestRequest) {
    const browserOptions = { embedUrl, referer, extraHeaders };

    if (directOk) {
        // Manifests usually work with minimal HTTP. TikTok segment URLs often 403
        // the proxy host — fall back to the open grandemx tab (cookies/UA) then unwrap.
        console.log('  - Fetch mode: direct HTTP (d=1, minimal headers)');
        const httpResponse = await fetchViaHttp(
            streamUrl,
            referer,
            extraHeaders,
            isManifestRequest,
            { minimal: true }
        );
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            return { response: httpResponse, mode: 'http' };
        }
        if (!isManifestRequest && embedUrl) {
            console.log(
                `  - Direct HTTP ${httpResponse.statusCode}; falling back to Chromium for segment`
            );
            const browserResponse = await fetchViaBrowser(
                streamUrl,
                browserOptions,
                isManifestRequest
            );
            return { response: browserResponse, mode: 'chromium' };
        }
        return { response: httpResponse, mode: 'http' };
    }

    console.log('  - Fetch mode: Chromium');
    const browserResponse = await fetchViaBrowser(streamUrl, browserOptions, isManifestRequest);
    return { response: browserResponse, mode: 'chromium' };
}

async function resolvePlaybackContext(
    embedUrl,
    streamUrl,
    feedReferer,
    feedHeaders,
    feedDirectOk,
    { isManifest = false } = {}
) {
    if (!embedUrl) {
        return {
            upstreamUrl: streamUrl,
            referer: feedReferer,
            extraHeaders: feedHeaders,
            directOk: feedDirectOk,
            manifestBaseUrl: streamUrl,
            resolvedFromEmbed: false,
        };
    }

    // TimStreams (d=1): open grandemx once (cached) for a fresh signed m3u8 + cookies.
    // Segments stay on /proxy so WebP-TS can be unwrapped for Roku; fetch tries HTTP
    // then Chromium when TikTok 403s the proxy host.
    if (feedDirectOk) {
        let stream = getCachedStream(embedUrl);
        if (!stream) {
            console.log('  - TimStreams: opening embed for signed m3u8 + segment cookies');
            try {
                stream = await getResolvedStream(embedUrl);
            } catch (err) {
                // Chrome SIGSEGV / launch failures used to 500 every Roku play.
                // Fall back to the feed's signed URL over plain HTTP.
                console.error(
                    `  - Embed resolve failed (${err.message}); using feed URL via HTTP`
                );
                return {
                    upstreamUrl: streamUrl,
                    referer: feedReferer,
                    extraHeaders: feedHeaders,
                    directOk: true,
                    manifestBaseUrl: streamUrl,
                    resolvedFromEmbed: false,
                };
            }
        }
        const freshUrl = stream.streamUrl || streamUrl;
        const useFresh = isManifest && Boolean(stream.streamUrl);
        return {
            upstreamUrl: useFresh ? freshUrl : streamUrl,
            referer: stream.referer || feedReferer,
            extraHeaders: {},
            directOk: true,
            manifestBaseUrl: useFresh ? freshUrl : streamUrl,
            resolvedFromEmbed: useFresh && stream.streamUrl !== streamUrl,
        };
    }

    // Streamed embeds: keep the player open/resolved (referer + headers and live
    // manifest capture). Rebase feed URLs onto the live CDN token from resolve —
    // otherwise we either serve the captured master for every mono.m3u8 (nested
    // /high/high/ rewrite) or 403 on the stale feed path.
    let stream = getCachedStream(embedUrl);
    if (!stream) {
        try {
            stream = await getResolvedStream(embedUrl);
        } catch (err) {
            console.error(
                `  - Embed resolve failed (${err.message}); using feed URL via HTTP`
            );
            return {
                upstreamUrl: streamUrl,
                referer: feedReferer,
                extraHeaders: feedHeaders,
                directOk: true,
                manifestBaseUrl: streamUrl,
                resolvedFromEmbed: false,
            };
        }
    }

    let upstreamUrl = streamUrl;
    let manifestBaseUrl = streamUrl;
    let resolvedFromEmbed = false;

    if (isManifest && stream.streamUrl) {
        const masterBody = stream.manifestBody || '';
        const isMaster = masterBody.includes('#EXT-X-STREAM-INF');
        if (isMaster) {
            let reqSuffix = '';
            try {
                reqSuffix = qualityPathSuffix(new URL(streamUrl).pathname);
            } catch {
                reqSuffix = '';
            }
            const variants = masterVariantSuffixes(masterBody);
            if (!reqSuffix || reqSuffix === 'playlist.m3u8' || !variants.has(reqSuffix)) {
                upstreamUrl = stream.streamUrl;
                manifestBaseUrl = stream.streamUrl;
                resolvedFromEmbed = stream.streamUrl !== streamUrl;
                if (resolvedFromEmbed) {
                    console.log(`  - Streamed: serving live master (${stream.streamUrl.slice(0, 80)}...)`);
                }
            } else {
                const rebased = rebaseOntoFreshMaster(streamUrl, stream.streamUrl);
                if (rebased) {
                    upstreamUrl = rebased;
                    manifestBaseUrl = rebased;
                    resolvedFromEmbed = rebased !== streamUrl;
                    if (resolvedFromEmbed) {
                        console.log(`  - Streamed: rebased variant → ${rebased.slice(0, 100)}...`);
                    }
                }
            }
        } else if (stream.streamUrl !== streamUrl) {
            upstreamUrl = stream.streamUrl;
            manifestBaseUrl = stream.streamUrl;
            resolvedFromEmbed = true;
        }
    }

    return {
        upstreamUrl,
        referer: stream.referer,
        extraHeaders: stream.requestHeaders,
        directOk: stream.directFetchOk,
        manifestBaseUrl,
        resolvedFromEmbed,
    };
}

// Format: /proxy/{BASE64_JSON_PAYLOAD} where payload is { u, r, h?, e?, d? }
// Use a named wildcard so standard base64 `/` inside the payload is not truncated
// by Express's single-segment `:param` matcher (TimStreams TikTok segment rewrites).
app.get('/proxy/*b64Payload', async (req, res) => {
    const b64Payload = extractB64Payload(req.params.b64Payload);
    if (!b64Payload) {
        res.status(400).send('Missing proxy payload');
        return;
    }
    const { url: streamUrl, referer, extraHeaders, embedUrl, directOk } = decodeProxyPayload(b64Payload);
    const isManifestRequest = isManifestUrl(streamUrl);

    console.log(`---\n[${new Date().toISOString()}] New request`);
    console.log(`  - Client IP: ${req.ip}`);
    console.log(`  - Request URL (from feed/rewrite): ${streamUrl}`);
    console.log(`  - Request type: ${isManifestRequest ? 'manifest' : 'segment/key'}`);
    console.log(`  - Embed page (e): ${embedUrl || '(missing — re-scrape feed)'}`);

    if (!isManifestRequest && !isHlsMediaUri(streamUrl)) {
        console.log(`  - Rejecting non-HLS media URL (not a segment): ${streamUrl.slice(0, 100)}`);
        res.status(404).send('Not an HLS media URL');
        return;
    }

    try {
        let ctx = await resolvePlaybackContext(
            embedUrl,
            streamUrl,
            referer,
            extraHeaders,
            directOk,
            { isManifest: isManifestRequest }
        );

        if (ctx.resolvedFromEmbed) {
            console.log(`  - Ignoring feed m3u8; using fresh resolve: ${ctx.upstreamUrl}`);
        }

        let response;
        let mode;

        ({ response, mode } = await fetchUpstream(
            ctx.upstreamUrl,
            {
                embedUrl,
                referer: ctx.referer,
                extraHeaders: ctx.extraHeaders,
                directOk: ctx.directOk,
            },
            isManifestRequest
        ));

        if (response.statusCode >= 300 && isManifestRequest && embedUrl) {
            console.log(`  - Manifest fetch failed (${response.statusCode}), re-resolving from embed...`);
            clearResolvedStream(embedUrl);
            ctx = await resolvePlaybackContext(
                embedUrl,
                streamUrl,
                referer,
                extraHeaders,
                directOk,
                { isManifest: true }
            );
            ({ response, mode } = await fetchUpstream(
                ctx.upstreamUrl,
                {
                    embedUrl,
                    referer: ctx.referer,
                    extraHeaders: ctx.extraHeaders,
                    directOk: ctx.directOk,
                },
                isManifestRequest
            ));
        }

        console.log(`  - Received response with status ${response.statusCode} (${mode}).`);

        if (response.statusCode < 200 || response.statusCode >= 300) {
            const bodyPreview = typeof response.body === 'string'
                ? response.body.slice(0, 200)
                : '';
            console.error(`  - Upstream rejected the request (${response.statusCode}).`);
            if (debug && bodyPreview) {
                console.error(`  - Response preview: ${bodyPreview}`);
            }
            if (
                response.statusCode === 403 &&
                !isManifestRequest &&
                directOk &&
                embedUrl
            ) {
                console.log('  - Clearing TimStreams embed cache after segment 403');
                clearResolvedStream(embedUrl);
            }
            res.status(response.statusCode).send(`Upstream returned ${response.statusCode}`);
            return;
        }

        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');

        if (isManifestRequest) {
            const playlist = typeof response.body === 'string'
                ? response.body
                : response.body.toString('utf8');

            if (!playlist.includes('#EXTM3U')) {
                console.error(`  - ERROR: manifest body empty or invalid (${playlist.length} chars)`);
                res.status(502).send('Upstream manifest empty or invalid');
                return;
            }

            const segmentHost = rewriteProxyHost(req);
            const loopback = isLoopbackClient(req);
            // ffmpeg remux: loopback host + omit bulky feed headers so segment
            // URLs stay under HLS demuxer limits (LAN PROXY_HOST is unreachable
            // from inside the container anyway).
            const rewriteHeaders = loopback ? {} : ctx.extraHeaders;
            console.log(
                `  - Rewriting manifest segment URLs through /proxy (${segmentHost}`
                + `${loopback ? ', remux-loopback' : ''})...`
            );

            // Master playlists must rewrite relative to the live master URL, not
            // the feed's mono.m3u8 path (that produced /high/high/ nesting).
            let rewriteBase = ctx.manifestBaseUrl || streamUrl;
            if (playlist.includes('#EXT-X-STREAM-INF') && embedUrl) {
                const cached = getCachedStream(embedUrl);
                if (cached?.streamUrl) {
                    rewriteBase = cached.streamUrl;
                    console.log(`  - Master rewrite base: ${rewriteBase.slice(0, 100)}...`);
                }
            }

            const KEY_TAG = '#EXT-X-KEY:';
            const rewrittenLines = [];
            let segmentCount = 0;
            for (const line of playlist.split('\n')) {
                if (line.startsWith(KEY_TAG)) {
                    const uriMatch = line.match(/URI="([^"]+)"/);
                    if (uriMatch?.[1]) {
                        const fullKeyUrl = new URL(uriMatch[1], rewriteBase).href;
                        const proxiedKeyUrl = `http://${segmentHost}/proxy/${buildRewrittenPayload(
                            fullKeyUrl,
                            ctx.referer,
                            rewriteHeaders,
                            embedUrl,
                            ctx.directOk
                        )}`;
                        rewrittenLines.push(line.replace(uriMatch[1], proxiedKeyUrl));
                        continue;
                    }
                }

                const trimmed = line.trim();
                if (trimmed.length > 0 && !trimmed.startsWith('#')) {
                    if (!isHlsMediaUri(trimmed)) {
                        console.log(`  - Skipping unrecognized line: ${trimmed.slice(0, 80)}`);
                        continue;
                    }
                    const segmentUrl = new URL(trimmed, rewriteBase).href;
                    rewrittenLines.push(`http://${segmentHost}/proxy/${buildRewrittenPayload(
                        segmentUrl,
                        ctx.referer,
                        rewriteHeaders,
                        embedUrl,
                        ctx.directOk
                    )}`);
                    segmentCount++;
                    continue;
                }

                rewrittenLines.push(line);
            }

            if (segmentCount === 0) {
                console.error('  - ERROR: manifest has no segment URLs after rewrite');
                res.status(502).send('Manifest has no segments');
                return;
            }

            console.log(`  - Rewrote ${segmentCount} segment URL(s)`);
            const rewrittenPlaylist = rewrittenLines.join('\n');

            res.setHeader('Content-Type', 'application/vnd.apple.mpegurl');
            res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
            logManifestPreview('Sending manifest to client', rewrittenPlaylist);
            res.send(rewrittenPlaylist);
        } else {
            const segmentBody = unwrapDisguisedSegment(response.body);
            console.log('  - Piping segment to client...');
            res.setHeader('Content-Type', 'video/MP2T');
            res.send(segmentBody);
        }
    } catch (error) {
        console.error(`  - ERROR processing request:`, error.message);
        if (debug) {
            console.error(error);
        }
        if (!res.headersSent) {
            res.status(500).send(`Failed to proxy stream: ${error.message}`);
        }
    }
});

http.createServer(app).listen(port, () => {
    console.log(`Advanced HLS Proxy server listening at http://localhost:${port}`);
});

// SIGINT/SIGTERM cleanup (including remux ffmpeg) lives in browser-fetch.js.
