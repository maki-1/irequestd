#!/usr/bin/env node
/**
 * Compares every field present in the MongoDB documents against the columns
 * the Prisma schema defines, so nothing is silently dropped by the migration.
 *
 *   node scripts/check-field-coverage.js
 *
 * Reports, per collection: fields in Mongo with no corresponding Prisma field,
 * and how many documents actually carry each one.
 */
require('dotenv/config');
const mongoose = require('mongoose');
const prisma = require('../lib/prisma');

// Mongo field → Prisma field, where the two genuinely differ.
const ALIASES = {
  users: { _id: 'legacyId', __v: null },
  admins: { _id: 'legacyId', __v: null },
  verificationprofiles: { _id: 'legacyId', __v: null, user: 'userId', reviewedBy: 'reviewedById' },
  requests: { _id: 'legacyId', __v: null, user: 'userId' },
  completed_documents: { _id: 'legacyId', __v: null, user: 'userId', request: 'requestId' },
  documentprices: { _id: 'legacyId', __v: null },
  purok_clearance_fee: { _id: 'legacyId', __v: null },
  counters: { _id: 'id', __v: null },
  documents: { _id: 'legacyId', __v: null, createdBy: 'createdById' },
  payments: { _id: 'legacyId', __v: null, user: 'userId', document: 'documentId', requests: 'legacyRequestIds' },
  audittrails: { _id: 'legacyId', __v: null, user: 'adminId' },
  notifications: { _id: 'legacyId', __v: null, user: 'adminId' },
  otps: null, // intentionally not migrated
};

const MODEL_FOR = {
  users: 'User',
  admins: 'Admin',
  verificationprofiles: 'VerificationProfile',
  requests: 'Request',
  completed_documents: 'CompletedDocument',
  documentprices: 'DocumentPrice',
  purok_clearance_fee: 'PurokClearanceFee',
  counters: 'Counter',
  documents: 'Document',
  payments: 'Payment',
  audittrails: 'AuditTrail',
  notifications: 'Notification',
};

async function main() {
  await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 15000 });
  const db = mongoose.connection.db;

  // Prisma exposes the parsed datamodel at runtime.
  const dmmf = prisma._runtimeDataModel ?? require('@prisma/client').Prisma.dmmf?.datamodel;
  const fieldsOf = (modelName) => {
    const model = dmmf.models?.[modelName] ?? dmmf.models?.find?.((m) => m.name === modelName);
    if (!model) return null;
    return new Set(model.fields.map((f) => f.name));
  };

  let problems = 0;

  for (const [collection, modelName] of Object.entries(MODEL_FOR)) {
    const exists = await db.listCollections({ name: collection }).toArray();
    if (!exists.length) continue;

    const docs = await db.collection(collection).find({}).toArray();
    if (!docs.length) {
      console.log(`${collection.padEnd(24)} (empty)`);
      continue;
    }

    const prismaFields = fieldsOf(modelName);
    if (!prismaFields) {
      console.log(`${collection.padEnd(24)} ! no Prisma model "${modelName}"`);
      problems++;
      continue;
    }

    const alias = ALIASES[collection] || {};
    const missing = [];

    const mongoFields = new Set();
    docs.forEach((d) => Object.keys(d).forEach((k) => mongoFields.add(k)));

    for (const field of mongoFields) {
      if (field in alias) {
        const mapped = alias[field];
        if (mapped === null) continue;          // deliberately dropped
        if (prismaFields.has(mapped)) continue; // mapped to a real column
        missing.push(`${field} → ${mapped}?`);
        continue;
      }
      if (prismaFields.has(field)) continue;
      const n = docs.filter((d) => d[field] !== undefined).length;
      missing.push(`${field} (${n}/${docs.length} docs)`);
    }

    if (missing.length) {
      problems += missing.length;
      console.log(`${collection.padEnd(24)} ${missing.length} unmapped:`);
      missing.sort().forEach((m) => console.log(`    - ${m}`));
    } else {
      console.log(`${collection.padEnd(24)} ok (${mongoFields.size} fields, ${docs.length} docs)`);
    }
  }

  console.log(
    problems === 0
      ? '\nEvery Mongo field maps to a Prisma column.'
      : `\n${problems} field(s) have no destination — they would be dropped.`
  );

  await prisma.$disconnect();
  await mongoose.disconnect();
  process.exit(problems === 0 ? 0 : 1);
}

main().catch(async (e) => {
  console.error('check failed:', e.message);
  try { await prisma.$disconnect(); } catch {}
  try { await mongoose.disconnect(); } catch {}
  process.exit(2);
});
