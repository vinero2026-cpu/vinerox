# VINEROX Blitz Arena — vinero.app/blitz

Standalone Next.js product for the 2-minute head-to-head financial esports mode described in
`VINEROX_MASTER_ARCHITECTURE.md`. Ships independently of the Flutter app so it can go live at
`https://vinero.app/blitz` first, then get ported into the native shell once the loop is proven.

## Stack
- **Next.js 14 (App Router) + TypeScript + Tailwind** — UI, onboarding, lobby, loadout, match screens.
- **API routes (`/api/profile`, `/api/match/start`, `/api/match/result`, `/api/chest/open`)** backed by a
  dependency-free JSON file store (`.data/blitz.json`) for server-side wallet/trophy bookkeeping — no
  native module / build toolchain required.
- **Standalone WebSocket server** (`server/ws-server.ts`, run with `npm run ws`) for real-time human
  matchmaking with automatic bot fallback after `BOT_FALLBACK_SECONDS` (7s).
- **Zustand + localStorage** as the client source of truth so the game is fully playable offline/standalone
  even if the API or WS server is unreachable — every server call is best-effort.
- **Canvas-based chart + particle background + Web Audio synthesized sound engine** — no external asset
  licenses required; reuses `vinero.mp3` / `backdrop.jpg` from the main app's brand assets.

## Local development
```bash
npm install
npm run dev:all   # starts Next.js on :3000/blitz AND the WS matchmaking server on :4001
```
Open http://localhost:3000/blitz

Run them separately if preferred: `npm run dev` and `npm run ws`.

## Production deploy (vinero.app/blitz)
1. `npm run build && npm run start` (or deploy to Vercel/hosting of choice) behind a reverse proxy path
   rule that routes `vinero.app/blitz/*` to this app (the app already sets `basePath: '/blitz'`).
2. Run the WebSocket server as a long-lived process (systemd/pm2) and expose it over `wss://` through the
   same reverse proxy (e.g. `vinero.app/blitz-ws` → `localhost:4001`), then set
   `NEXT_PUBLIC_BLITZ_WS_URL=wss://vinero.app/blitz-ws` at build time.
3. Mount a persistent volume for `.data/` so `blitz.json` survives deploys.

## Known limitations (intentional, documented — not hidden)
- Wallet/trophy truth currently lives client-side (localStorage) for resilience; the API routes persist a
  parallel server record but nothing yet reconciles them if they drift. Before real-money stakes go live,
  make the server the single source of truth and gate the client UI on its response.
- The WebSocket server matches any two queued players regardless of stake parity — add stake-bucket
  matching before launch.
- Bot difficulty and call-resolution odds are tuned for a fun demo loop, not statistically audited fairness.
