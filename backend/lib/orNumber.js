const prisma = require('./prisma');

// Port of the Mongo pre('save') hook that generated OR numbers from the
// `Counter` collection. The upsert below is a single atomic statement, so
// concurrent requests can't be handed the same sequence number.
async function nextOrNumber(client = prisma) {
  const year = new Date().getFullYear();

  const counter = await client.counter.upsert({
    where: { id: `orNumber-${year}` },
    create: { id: `orNumber-${year}`, seq: 1 },
    update: { seq: { increment: 1 } },
  });

  return `OR-${year}-${String(counter.seq).padStart(5, '0')}`;
}

module.exports = { nextOrNumber };
