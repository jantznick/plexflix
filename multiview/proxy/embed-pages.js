import { safeClosePage } from '../src/puppeteer-utils.js';

/** @type {Map<string, import('puppeteer').Page>} */
const embedPages = new Map();

export function setEmbedPage(embedUrl, page) {
    const existing = embedPages.get(embedUrl);
    if (existing && existing !== page && !existing.isClosed()) {
        void safeClosePage(existing);
    }
    embedPages.set(embedUrl, page);
}

export function getEmbedPage(embedUrl) {
    const page = embedPages.get(embedUrl);
    if (page && !page.isClosed()) {
        return page;
    }
    embedPages.delete(embedUrl);
    return null;
}

export function clearEmbedPage(embedUrl) {
    const page = embedPages.get(embedUrl);
    if (page) {
        void safeClosePage(page);
    }
    embedPages.delete(embedUrl);
}

export function clearAllEmbedPages() {
    for (const page of embedPages.values()) {
        void safeClosePage(page);
    }
    embedPages.clear();
}
