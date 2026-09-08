#!/usr/bin/env node
/**
 * Fills verification_profiles.purok from the existing free-text address.
 *
 *   node scripts/backfill-purok.js            # report only
 *   node scripts/backfill-purok.js --commit   # write
 *
 * Only rows where the address resolves to a configured purok are touched;
 * anything ambiguous is listed and left alone rather than guessed at.
 */
require('dotenv/config');
const prisma = require('../lib/prisma');
const { matchPurok } = require('../lib/purokFee');

const COMMIT = process.argv.includes('--commit');

async function main() {
  const fees = await prisma.purokClearanceFee.findMany();
  const profiles = await prisma.verificationProfile.findMany({
    select: { id: true, fullName: true, address: true, purok: true },
  });

  let filled = 0, already = 0, unresolved = [];

  for (const p of profiles) {
    if (p.purok) { already++; continue; }

    const matched = matchPurok(p.address, fees);
    if (!matched) { unresolved.push(p); continue; }

    if (COMMIT) {
      await prisma.verificationProfile.update({
        where: { id: p.id },
        data: { purok: matched.purokName },
      });
    }
    filled++;
  }

  console.log(`profiles:        ${profiles.length}`);
  console.log(`already set:     ${already}`);
  console.log(`${COMMIT ? 'filled' : 'would fill'}:      ${filled}`);
  console.log(`unresolved:      ${unresolved.length}`);

  if (unresolved.length) {
    console.log('\nleft alone — address does not name a configured purok:');
    unresolved.forEach((p) => console.log(`  ${p.fullName || '(no name)'} — ${p.address || '(blank)'}`));
    console.log('\nThese need a purok chosen by hand, or by the resident on their next update.');
  }

  if (!COMMIT) console.log('\nDRY RUN — re-run with --commit to write.');

  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error('backfill failed:', e.message);
  try { await prisma.$disconnect(); } catch {}
  process.exit(1);
});
