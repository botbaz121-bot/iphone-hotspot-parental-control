# SpotChecker Web Parent (`web.spotchecker.app`)

Static web parent dashboard for household management, co-parent invites, and child policy controls.

## Features in this phase
- Apple web sign-in via backend (`/auth/apple/start` + `/auth/apple/callback`)
- Parent dashboard (children list + core policy toggles + day schedule + daily limit)
- Household members view
- Co-parent invite creation (email optional), link and code display
- Invite acceptance by token and by code (`/invite`)
- Pairing-code generation and events viewing per child
- Owner-only child deletion enforced by backend

## Files
- `index.html` + `app.js` + `styles.css` (dashboard)
- `invite/index.html` (invite accept page)

## Backend env required
- `WEB_APP_REDIRECT_URL=https://web.spotchecker.app/`
- `CORS_ALLOW_ORIGINS=https://web.spotchecker.app,http://localhost:5173,http://localhost:3000`
- existing Apple auth env vars must already be configured

## Deploy
Host this folder as static site at `web.spotchecker.app`.

If your host supports SPA rewrites, route unknown paths to `/index.html` and keep `/invite` mapped to `invite/index.html`.
