import fs from 'fs';
import path from 'path';
import puppeteer from 'puppeteer';
import puppeteerExtra from 'puppeteer-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';

let stealthApplied = false;

function applyStealth() {
    if (stealthApplied) return;
    puppeteerExtra.use(StealthPlugin());
    stealthApplied = true;
}

/** Prefer a real Chrome binary when present (passes CF more often than bundled Chromium). */
function resolveChromeExecutable() {
    // Host .env often sets this for the scraper; Docker compose may inject it even
    // though the binary is not inside the container. Only honor paths that exist.
    const fromEnv = process.env.PUPPETEER_EXECUTABLE_PATH?.trim();
    if (fromEnv && fs.existsSync(fromEnv)) {
        return fromEnv;
    }
    const candidates = [
        '/usr/bin/google-chrome-stable',
        '/usr/bin/google-chrome',
        '/usr/local/bin/google-chrome',
        '/usr/bin/chromium-browser',
        '/usr/bin/chromium',
    ];
    for (const candidate of candidates) {
        if (fs.existsSync(candidate)) return candidate;
    }
    return undefined;
}

function dockerChromeArgs() {
    // Chrome 148+ has been segfaulting (signal 11 SI_KERNEL) in slim Docker
    // hosts — usually GPU/SwiftShader, dbus, or zygote. Keep the surface tiny.
    return [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--disable-extensions',
        '--disable-background-networking',
        '--disable-default-apps',
        '--disable-sync',
        '--disable-translate',
        '--hide-scrollbars',
        '--metrics-recording-only',
        '--mute-audio',
        '--no-first-run',
        '--no-zygote',
        '--disable-dbus',
        '--disable-features=TranslateUI,BlinkGenPropertyTrees,AudioServiceOutOfProcess,IsolateOrigins,site-per-process',
        '--disable-blink-features=AutomationControlled',
        '--window-size=1366,768',
        '--lang=en-US,en',
    ];
}

/** Shared Puppeteer launch options for scraper and proxy. */
export function getPuppeteerLaunchOptions() {
    // Visible by default for local debugging. Headless when:
    // - PROXY_HEADLESS=true (server / Docker), or
    // - running inside a Docker container (no X display).
    const inDocker = fs.existsSync('/.dockerenv');
    const headless = process.env.PROXY_HEADLESS === 'true' || inDocker;
    const executablePath = resolveChromeExecutable();
    // New headless (full Chrome) has been SIGSEGV'ing in our containers.
    // chrome-headless-shell is the stable Docker path; override with PROXY_HEADLESS_MODE.
    const mode = (process.env.PROXY_HEADLESS_MODE || (inDocker || headless ? 'shell' : 'true')).trim();
    const headlessOpt = headless
        ? (mode === 'true' || mode === 'new' ? true : mode === 'old' ? 'old' : 'shell')
        : false;

    return {
        headless: headlessOpt,
        ...(executablePath ? { executablePath } : {}),
        args: headless || inDocker
            ? dockerChromeArgs()
            : [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu',
                '--disable-blink-features=AutomationControlled',
                '--window-size=1366,768',
                '--lang=en-US,en',
                '--start-maximized',
            ],
        defaultViewport: headless
            ? { width: 1366, height: 768, deviceScaleFactor: 1 }
            : null,
        ignoreHTTPSErrors: true,
        // Avoid pipe transport flakes on some Docker kernels
        dumpio: process.env.PROXY_DEBUG === 'true',
    };
}

/**
 * Launch Chromium/Chrome with stealth patches applied.
 * Prefer this over raw `puppeteer.launch` for callers that need the base module.
 * Tries headless shell first in Docker; on SIGSEGV-style launch failure, retries
 * once with full headless Chrome.
 */
export async function launchBrowser(extraOptions = {}) {
    applyStealth();
    const base = getPuppeteerLaunchOptions();
    const options = { ...base, ...extraOptions };
    if (extraOptions.args && base.args) {
        // Callers usually want to append, not wipe Docker hardening args
        options.args = [...base.args, ...extraOptions.args];
    }

    try {
        return await puppeteerExtra.launch(options);
    } catch (firstErr) {
        const triedShell = options.headless === 'shell';
        if (!triedShell) throw firstErr;
        console.warn(
            `[puppeteer] headless shell launch failed (${firstErr.message}); retrying full Chrome headless`
        );
        return puppeteerExtra.launch({ ...options, headless: true });
    }
}

export function describePuppeteerMode() {
    const inDocker = fs.existsSync('/.dockerenv');
    const executablePath = resolveChromeExecutable();
    const browserLabel = executablePath
        ? `chrome (${path.basename(executablePath)})`
        : 'bundled-chromium';
    const opts = getPuppeteerLaunchOptions();
    const headlessLabel = opts.headless === false
        ? 'visible'
        : opts.headless === 'shell'
            ? 'headless-shell'
            : 'headless';
    if (process.env.PROXY_HEADLESS === 'true' || inDocker) {
        return inDocker
            ? `${headlessLabel}+stealth (docker, ${browserLabel})`
            : `${headlessLabel}+stealth (${browserLabel})`;
    }
    return `${headlessLabel}+stealth (${browserLabel})`;
}

/** Raw puppeteer export for callers that need the base module. */
export { puppeteer };
