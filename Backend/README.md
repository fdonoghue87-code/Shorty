# Shorty Schedule Backend

A tiny Cloudflare Worker that lets Shorty's "smart" schedule import (Shorty Plus only)
send a photo to Claude's vision API for much more accurate reading than on-device OCR.
It holds the real Anthropic API key so the app itself never has to -- an API key baked
into an iOS app can always be extracted from the binary, which is exactly what this
avoids. It stores nothing: each request is stateless, in and out.

## One-time setup

You'll need:
1. A [Cloudflare account](https://dash.cloudflare.com/sign-up) (free tier is plenty for this).
2. An [Anthropic API key](https://console.anthropic.com/) — this is a **separate, pay-as-you-go
   developer key**, not your regular claude.ai login. You'll need billing set up there; each
   schedule photo costs a small fraction of a cent to a few cents depending on image size.

## Deploy

```bash
cd Backend
npm install -g wrangler   # Cloudflare's CLI, one-time
wrangler login             # opens a browser to authorize your Cloudflare account

# Set your two secrets (you'll be prompted to paste each value -- they're never written to disk here):
wrangler secret put ANTHROPIC_API_KEY
wrangler secret put SHARED_SECRET
# ^ SHARED_SECRET can be any random string you make up, e.g. run: openssl rand -hex 32
#   Whatever you pick here must exactly match SmartScheduleImportService.swift's
#   `sharedSecret` constant in the iOS app.

wrangler deploy
```

That last command prints your Worker's live URL, something like:

```
https://shorty-schedule-backend.<your-subdomain>.workers.dev
```

Copy that URL into `SmartScheduleImportService.swift`'s `endpoint` constant back in the
Shorty Xcode project, and copy the same `SHARED_SECRET` value into that file's
`sharedSecret` constant. Then rebuild the app.

## Cost control

Since this is gated behind Shorty Plus in the app (only subscribers can trigger it, and
it falls back to free on-device OCR for everyone else or on any network/API error),
your exposure is bounded by how many Plus subscribers you actually have. Still worth
keeping an eye on usage/billing at [console.anthropic.com](https://console.anthropic.com/)
periodically, especially early on.

## Updating

Change `worker.js`, then just run `wrangler deploy` again from this folder. No app
changes needed unless the request/response shape itself changes.
