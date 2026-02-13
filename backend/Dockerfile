FROM node:22-bookworm-slim

WORKDIR /app

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
