const prisma = require('../lib/prisma');

// Prisma connects lazily on the first query; this just fails fast at boot the
// way the old mongoose.connect() did, rather than surfacing on a user request.
async function connectDB() {
  try {
    await prisma.$queryRaw`SELECT 1`;
    console.log('Postgres connected');
  } catch (err) {
    console.error('Postgres connection error:', err.message);
    process.exit(1);
  }
}

module.exports = connectDB;
