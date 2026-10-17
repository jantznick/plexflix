Vendored from https://github.com/jantznick/roku-feed (`proxy/` + shared `src/` imports).
Same advanced-proxy the LAN sidecar runs on `:8787` — started in-container by
`../entrypoint.sh` on `:18787` for mosaic only.

When fixing Chrome / Puppeteer launch bugs, keep this tree and roku-feed in sync.
A ready-to-apply patch for the LAN `:8787` service lives at:

```
multiview/patches/roku-feed-chrome-sigsegv.patch
```

On the roku-feed host:

```bash
cd /path/to/roku-feed
git apply /path/to/plexflix/multiview/patches/roku-feed-chrome-sigsegv.patch
docker compose -f proxy/docker-compose.yml up -d --build
```

Confirm the new process logs `embed-first-v22-chrome-shell` on startup.
