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

/** Shared Puppeteer launch options for scraper and proxy. */
export function getPuppeteerLaunchOptions() {
    // Visible by default for local debugging. Headless when:
    // - PROXY_HEADLESS=true (server / Docker), or
    // - running inside a Docker container (no X display).
    const inDocker = fs.existsSync('/.dockerenv');
    const headless = process.env.PROXY_HEADLESS === 'true' || inDocker;
    const executablePath = resolveChromeExecutable();

    return {
        // New headless is less bot-like than the old headless shell.
        headless: headless ? true : false,
        ...(executablePath ? { executablePath } : {}),
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--disable-blink-features=AutomationControlled',
            '--window-size=1366,768',
            '--lang=en-US,en',
            ...(headless ? [] : ['--start-maximized']),
        ],
        defaultViewport: headless
            ? { width: 1366, height: 768, deviceScaleFactor: 1 }
            : null,
        ignoreHTTPSErrors: true,
    };
}

/**
 * Launch Chromium/Chrome with stealth patches applied.
 * Prefer this over raw `puppeteer.launch` for Cloudflare-fronted sites.
 */
export async function launchBrowser(extraOptions = {}) {
    applyStealth();
    const options = { ...getPuppeteerLaunchOptions(), ...extraOptions };
    const browser = await puppeteerExtra.launch(options);
    return browser;
}

export function describePuppeteerMode() {
    const inDocker = fs.existsSync('/.dockerenv');
    const executablePath = resolveChromeExecutable();
    const browserLabel = executablePath
        ? `chrome (${path.basename(executablePath)})`
        : 'bundled-chromium';
    if (process.env.PROXY_HEADLESS === 'true' || inDocker) {
        return inDocker
            ? `headless+stealth (docker, ${browserLabel})`
            : `headless+stealth (${browserLabel})`;
    }
    return `visible+stealth (${browserLabel})`;
}

/** Raw puppeteer export for callers that need the base module. */
export { puppeteer };
