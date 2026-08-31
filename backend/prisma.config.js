// Prisma 7 reads the datasource URL from here rather than schema.prisma.
// `directUrl` no longer exists — v7 opens a direct connection for migrations
// on its own, so a single pooled Neon URL in DATABASE_URL is enough.
require('dotenv/config');
const { defineConfig, env } = require('prisma/config');

module.exports = defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
});
