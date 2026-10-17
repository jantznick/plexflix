/**
 * Live HLS remux: copy video, re-encode audio to AAC-LC.
 *
 * Roku often rejects HE-AAC (`decoder:pump:Unsupported AAC stream`) that
 * browsers play fine. Clients hit /remux/{same-payload-as-proxy}; we ffmpeg
 * the loopback /proxy URL into a short sliding-window HLS playlist.
 */

import { spawn } from 'child_process';
import crypto from 'crypto';
import fs from 'fs';
import os from 'os';
import path from 'path';

const REMUX_ROOT = process.env.PROXY_REMUX_DIR
    || path.join(os.tmpdir(), 'roku-hls-remux');
const IDLE_MS = Number.parseInt(process.env.PROXY_REMUX_IDLE_MS || '', 10)
    || 10 * 60 * 1000;
const READY_MS = Number.parseInt(process.env.PROXY_REMUX_READY_MS || '', 10)
    || 45000;
const FF_BIN = process.env.FFMPEG || 'ffmpeg';
const port = process.env.PORT || 8787;
const LOOPBACK = process.env.PROXY_LOOPBACK || `http://127.0.0.1:${port}`;

/** @type {Map<string, RemuxSession>} */
const sessions = new Map();
/** @type {ReturnType<typeof setInterval> | null} */
let reapTimer = null;

/**
 * @typedef {{
 *   id: string,
 *   dir: string,
 *   proc: import('child_process').ChildProcess | null,
 *   lastUsed: number,
 *   readyPromise: Promise<void>,
 * }} RemuxSession
 */

function log(message) {
    console.log(`[audio-remux] ${message}`);
}

export function remuxSessionId(b64Payload) {
    return crypto.createHash('sha1').update(b64Payload).digest('hex').slice(0, 16);
}

function ensureRoot() {
    fs.mkdirSync(REMUX_ROOT, { recursive: true });
}

function scheduleReaper() {
    if (reapTimer) {
        return;
    }
    reapTimer = setInterval(() => {
        const now = Date.now();
        for (const [id, session] of sessions) {
            if (now - session.lastUsed > IDLE_MS) {
                log(`Idle timeout — stopping session ${id}`);
                void stopSession(id);
            }
        }
        if (sessions.size === 0 && reapTimer) {
            clearInterval(reapTimer);
            reapTimer = null;
        }
    }, 30_000);
    if (typeof reapTimer.unref === 'function') {
        reapTimer.unref();
    }
}

function waitForPlaylist(dir, timeoutMs) {
    const playlist = path.join(dir, 'index.m3u8');
    const deadline = Date.now() + timeoutMs;
    return new Promise((resolve, reject) => {
        const tick = () => {
            try {
                if (fs.existsSync(playlist)) {
                    const text = fs.readFileSync(playlist, 'utf8');
                    if (text.includes('#EXTINF') && (text.includes('.ts') || text.includes('.m4s'))) {
                        resolve(text);
                        return;
                    }
                }
            } catch {
                // Retry until deadline.
            }
            if (Date.now() >= deadline) {
                reject(new Error(`Remux playlist not ready within ${timeoutMs}ms`));
                return;
            }
            setTimeout(tick, 250);
        };
        tick();
    });
}

/**
 * @param {string} b64Payload
 * @returns {Promise<RemuxSession>}
 */
export async function ensureRemuxSession(b64Payload) {
    if (!b64Payload) {
        throw new Error('Missing remux payload');
    }

    const id = remuxSessionId(b64Payload);
    const existing = sessions.get(id);
    if (existing?.proc && existing.proc.exitCode === null && !existing.proc.killed) {
        existing.lastUsed = Date.now();
        await existing.readyPromise;
        return existing;
    }

    if (existing) {
        await stopSession(id);
    }

    ensureRoot();
    const dir = path.join(REMUX_ROOT, id);
    fs.rmSync(dir, { recursive: true, force: true });
    fs.mkdirSync(dir, { recursive: true });

    const inputUrl = `${LOOPBACK}/proxy/${b64Payload}`;
    const playlistPath = path.join(dir, 'index.m3u8');
    const segmentPattern = path.join(dir, 'seg%05d.ts');

    const args = [
        '-hide_banner',
        '-loglevel', 'warning',
        '-nostdin',
        // Proxied segment URLs have no .ts suffix; HLS demuxer rejects them
        // unless allowed_extensions is ALL ("not in allowed_segment_extensions").
        '-protocol_whitelist', 'file,http,https,tcp,tls,crypto',
        '-allowed_extensions', 'ALL',
        '-fflags', '+genpts+discardcorrupt',
        '-reconnect', '1',
        '-reconnect_streamed', '1',
        '-reconnect_delay_max', '5',
        '-rw_timeout', '15000000',
        '-i', inputUrl,
        '-map', '0:v:0',
        '-map', '0:a:0?',
        '-c:v', 'copy',
        '-c:a', 'aac',
        '-profile:a', 'aac_low',
        '-b:a', '128k',
        '-ac', '2',
        '-ar', '48000',
        '-f', 'hls',
        '-hls_time', '2',
        '-hls_list_size', '8',
        '-hls_flags', 'delete_segments+append_list+omit_endlist',
        '-hls_segment_filename', segmentPattern,
        playlistPath,
    ];

    log(`Starting ffmpeg session ${id}`);
    log(`  input: ${inputUrl.slice(0, 120)}...`);

    const proc = spawn(FF_BIN, args, {
        stdio: ['ignore', 'ignore', 'pipe'],
    });

    proc.stderr?.on('data', (chunk) => {
        const line = chunk.toString('utf8').trim();
        if (line) {
            log(`ffmpeg[${id}]: ${line.slice(0, 500)}`);
        }
    });

    proc.on('exit', (code, signal) => {
        log(`ffmpeg[${id}] exited code=${code} signal=${signal || ''}`);
        const current = sessions.get(id);
        if (current?.proc === proc) {
            current.proc = null;
        }
    });

    /** @type {RemuxSession} */
    const session = {
        id,
        dir,
        proc,
        lastUsed: Date.now(),
        readyPromise: waitForPlaylist(dir, READY_MS).then(() => {
            log(`Session ${id} playlist ready`);
        }),
    };
    sessions.set(id, session);
    scheduleReaper();

    try {
        await session.readyPromise;
    } catch (error) {
        await stopSession(id);
        throw error;
    }

    session.lastUsed = Date.now();
    return session;
}

export function touchRemuxSession(id) {
    const session = sessions.get(id);
    if (session) {
        session.lastUsed = Date.now();
    }
}

export async function stopSession(id) {
    const session = sessions.get(id);
    if (!session) {
        return;
    }
    sessions.delete(id);
    if (session.proc && session.proc.exitCode === null) {
        session.proc.kill('SIGTERM');
        await new Promise((resolve) => {
            const timer = setTimeout(() => {
                try {
                    session.proc?.kill('SIGKILL');
                } catch {
                    // ignore
                }
                resolve();
            }, 2000);
            session.proc?.once('exit', () => {
                clearTimeout(timer);
                resolve();
            });
        });
    }
    try {
        fs.rmSync(session.dir, { recursive: true, force: true });
    } catch {
        // ignore
    }
}

export async function shutdownAudioRemux() {
    const ids = [...sessions.keys()];
    await Promise.all(ids.map((id) => stopSession(id)));
    if (reapTimer) {
        clearInterval(reapTimer);
        reapTimer = null;
    }
}

export function getRemuxRoot() {
    ensureRoot();
    return REMUX_ROOT;
}
