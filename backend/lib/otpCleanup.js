const prisma = require('./prisma');

// MongoDB expired OTPs automatically via a TTL index. Postgres has no
// equivalent, so expired rows are swept on an interval instead.
const SWEEP_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes

async function purgeExpiredOtps() {
  const { count } = await prisma.otpCode.deleteMany({
    where: { expiresAt: { lt: new Date() } },
  });
  if (count > 0) console.log(`[otp] purged ${count} expired code(s)`);
  return count;
}

function startOtpCleanup() {
  purgeExpiredOtps().catch((e) => console.error('[otp] sweep failed:', e.message));
  const timer = setInterval(
    () => purgeExpiredOtps().catch((e) => console.error('[otp] sweep failed:', e.message)),
    SWEEP_INTERVAL_MS
  );
  timer.unref(); // don't hold the process open
  return timer;
}

module.exports = { purgeExpiredOtps, startOtpCleanup };
