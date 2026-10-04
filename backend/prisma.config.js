// Prisma 7 reads the datasource URL from here rather than schema.prisma.
// Use Neon's direct endpoint for CLI migrations; the app's Prisma adapter
// continues using the pooled DATABASE_URL at runtime.
require('dotenv/config');
const { defineConfig } = require('prisma/config');

const migrationUrl = process.env.DIRECT_URL || process.env.DATABASE_URL;
if (!migrationUrl) {
  throw new Error('Set DIRECT_URL (recommended) or DATABASE_URL for Prisma migrations');
}

module.exports = defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: migrationUrl,
  },
});
