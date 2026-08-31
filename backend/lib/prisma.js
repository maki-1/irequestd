require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

// Prisma 7 connects through an explicit driver adapter rather than its own
// engine, so the pg pool is configured here.
const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
  // Neon's free tier caps connections; keep the local pool small.
  max: 5,
});

// Single shared client. Reused across hot-reloads in dev so nodemon restarts
// don't leak connections.
const prisma =
  global.__prisma ||
  new PrismaClient({
    adapter,
    log: process.env.NODE_ENV === 'production' ? ['error'] : ['warn', 'error'],
  });

if (process.env.NODE_ENV !== 'production') global.__prisma = prisma;

module.exports = prisma;
