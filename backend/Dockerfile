# syntax=docker/dockerfile:1

# Debian rather than Alpine: Prisma ships glibc engine binaries by default, so
# musl would need an extra binaryTarget in schema.prisma.
FROM node:22-slim

# openssl is required by Prisma; ca-certificates for outbound TLS to Neon,
# Cloudinary, PayMongo and Gmail SMTP.
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV NODE_ENV=production

# Dependencies first so this layer stays cached across code-only changes.
# devDependencies are kept on purpose: the prisma CLI is needed to run
# `migrate deploy` from the Koyeb console.
COPY package.json package-lock.json ./
RUN npm ci --include=dev

# `prisma generate` loads prisma.config.js, which reads DATABASE_URL. Nothing
# connects at build time, so a placeholder is enough — the real value comes
# from the Koyeb service env at runtime.
COPY prisma.config.js ./
COPY prisma ./prisma
RUN DATABASE_URL="postgresql://build:build@localhost:5432/build" npx prisma generate

COPY . .

# Koyeb injects PORT (8000 by default); server.js falls back to 5000 locally.
EXPOSE 8000

CMD ["node", "server.js"]
