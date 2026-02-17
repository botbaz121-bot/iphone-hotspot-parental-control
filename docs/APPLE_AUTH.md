# Sign in with Apple (Web) – Setup Notes

## Apple Developer Portal

### Identifiers
- **App ID (Bundle ID):** `com.bazapps.hotspotparent`
- **Service ID:** `com.bazapps.hotspotparent.web`

### Web Authentication
Configure **Service ID** → *Sign in with Apple* → **Web Authentication**:
- **Domain:** `hubz.com`
- **Return URL:** `https://hotspot.abomb.co.uk/auth/apple/callback`

### Keys
- Create a **Sign in with Apple** key and associate it with the *primary App ID*.
- Download the `.p8` file once.

## Render env vars

Required:
- `APPLE_TEAM_ID=3SJ44B3Q7Y`
- `APPLE_KEY_ID=<Key ID>`
- `APPLE_SERVICE_ID=com.bazapps.hotspotparent.web`
- `APPLE_REDIRECT_URI=https://hotspot.abomb.co.uk/auth/apple/callback`
- `APPLE_PRIVATE_KEY_PATH=/etc/secrets/AuthKey_<KeyID>.p8`

Secret file:
- `/etc/secrets/AuthKey_<KeyID>.p8` contents should be the Apple `.p8` private key.

## Endpoints

- `GET /auth/apple/start`
  - Redirects to Apple authorize endpoint
  - Uses `response_mode=form_post` and `scope=name email`
  - Creates a one-time `state` stored server-side in SQLite

- `POST /auth/apple/callback`
  - Expects `state` and `code` (and optional `user` JSON only on first consent)
  - Exchanges code for tokens via `https://appleid.apple.com/auth/token`

## Notes

- Apple requires `response_mode=form_post` when requesting `name` or `email`.
- The callback currently returns Apple token payload for debugging.
  Next step is to validate `id_token` and create a proper app session.
