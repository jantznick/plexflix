/** @returns {boolean} */
export function isBrowserConnectionError(error) {
    const message = error?.message || '';
    return (
        error?.name === 'ConnectionClosedError' ||
        message.includes('Connection closed') ||
        message.includes('Protocol error') ||
        message.includes('Target closed') ||
        message.includes('Session closed')
    );
}

/** @returns {boolean} */
export function isFrameDetachedError(error) {
    const message = error?.message || '';
    return (
        message.includes('frame was detached') ||
        message.includes('Frame detached') ||
        message.includes('Execution context was destroyed') ||
        message.includes('Cannot find context with specified id')
    );
}

/** Close a Puppeteer page without failing the scraper if the browser already died. */
export async function safeClosePage(page) {
    if (!page || page.isClosed()) {
        return;
    }

    try {
        await page.close();
    } catch (error) {
        if (!isBrowserConnectionError(error)) {
            console.warn(`-- Could not close browser page: ${error.message}`);
        }
    }
}

/** @returns {boolean} */
export function isBrowserConnected(browser) {
    return Boolean(browser && typeof browser.isConnected === 'function' && browser.isConnected());
}
