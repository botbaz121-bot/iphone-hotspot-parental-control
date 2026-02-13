FROM node:20-bookworm-slim

WORKDIR /app

# better-sqlite3 may need native build tooling (and Node 22 prebuilds may not exist)
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

# Install deps first (better build caching)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# App source
COPY src ./src

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3003

EXPOSE 3003

CMD ["npm","start"]
