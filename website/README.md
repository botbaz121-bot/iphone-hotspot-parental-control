# SpotChecker website

Static website for App Store support + privacy policy URLs.

## Local run

```bash
docker build -t spotchecker-site .
docker run --rm -p 8085:80 spotchecker-site
```

Open: http://localhost:8085

## Deploy (Coolify + existing nginx)

- Deploy this `website/` folder as a Dockerfile app in Coolify.
- Publish to an internal host port (e.g. 8085).
- Leave Coolify Domains blank.
- Add an nginx vhost for `spotchecker.app` -> `http://127.0.0.1:8085`.
- Optionally redirect `www.spotchecker.app` -> apex.
