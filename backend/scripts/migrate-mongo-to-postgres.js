#!/usr/bin/env node
/**
 * One-way data copy: MongoDB → Neon Postgres.
 *
 *   node scripts/migrate-mongo-to-postgres.js            # dry run, reports only
 *   node scripts/migrate-mongo-to-postgres.js --commit   # actually writes
 *   node scripts/migrate-mongo-to-postgres.js --commit --wipe   # clear PG first
 *
 * Reads from Mongo and never writes back to it, so it is safe to re-run. Every
 * row carries its original ObjectId in `legacyId`: that is both how relations
 * are remapped to UUIDs and how a re-run knows to skip rows already copied.
 *
 * Order matters — users are copied first, then everything that references them.
 */
require('dotenv/config');
const mongoose = require('mongoose');
const prisma = require('../lib/prisma');

const COMMIT = process.argv.includes('--commit');
const WIPE = process.argv.includes('--wipe');
// Re-copy every field onto rows that were imported by an earlier run, instead
// of skipping them. Used after the schema gains columns that a previous
// migration had no destination for. Updates in place — never deletes.
const REFRESH = process.argv.includes('--refresh');

const stats = [];
const report = (table, s) => stats.push({ table, ...s });

const oid = (v) => (v ? String(v) : null);
const str = (v, fallback = '') => (v === null || v === undefined ? fallback : String(v));
const date = (v) => {
  if (!v) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};
const int = (v, fallback = 0) => {
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : fallback;
};
const dec = (v, fallback = 0) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
};

// Mongo enum fields were free-form strings. Postgres enums are strict, so
// anything unrecognised falls back to the default instead of aborting the run.
const pick = (value, allowed, fallback) => {
  if (value === null || value === undefined) return fallback;
  const hit = allowed.find((a) => a.toLowerCase() === String(value).trim().toLowerCase());
  return hit ?? fallback;
};

// Create, or update in place when --refresh re-runs over an existing row.
const upsertProfile = (existingId, data) =>
  existingId
    ? prisma.verificationProfile.update({ where: { id: existingId }, data })
    : prisma.verificationProfile.create({ data });

async function collectionExists(db, name) {
  const found = await db.listCollections({ name }).toArray();
  return found.length > 0;
}

async function readAll(db, name) {
  if (!(await collectionExists(db, name))) {
    console.log(`  (collection "${name}" does not exist — skipping)`);
    return [];
  }
  return db.collection(name).find({}).toArray();
}

async function main() {
  if (!process.env.MONGO_URI) throw new Error('MONGO_URI is not set');

  await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 15000 });
  const db = mongoose.connection.db;
  console.log(`mongo:    ${db.databaseName}`);
  console.log(`mode:     ${COMMIT ? 'COMMIT (writing to Postgres)' : 'DRY RUN (no writes)'}\n`);

  if (WIPE) {
    if (!COMMIT) {
      console.log('--wipe ignored during a dry run.\n');
    } else {
      console.log('wiping existing Postgres rows...');
      await prisma.payment.deleteMany();
      await prisma.notification.deleteMany();
      await prisma.auditTrail.deleteMany();
      await prisma.document.deleteMany();
      await prisma.otpCode.deleteMany();
      await prisma.completedDocument.deleteMany();
      await prisma.request.deleteMany();
      await prisma.verificationProfile.deleteMany();
      await prisma.user.deleteMany();
      await prisma.admin.deleteMany();
      await prisma.documentPrice.deleteMany();
      await prisma.purokClearanceFee.deleteMany();
      await prisma.counter.deleteMany();
      console.log('wiped.\n');
    }
  }

  // legacy ObjectId hex → new UUID
  const userIds = new Map();
  const requestIds = new Map();

  // Seed from anything already in Postgres so re-runs are idempotent.
  for (const u of await prisma.user.findMany({ select: { id: true, legacyId: true } })) {
    if (u.legacyId) userIds.set(u.legacyId, u.id);
  }
  for (const r of await prisma.request.findMany({ select: { id: true, legacyId: true } })) {
    if (r.legacyId) requestIds.set(r.legacyId, r.id);
  }

  // ── users ───────────────────────────────────────────────────────────────────
  console.log('users');
  {
    const docs = await readAll(db, 'users');
    let written = 0, skipped = 0, failed = 0;
    // Mongo stored '' for a missing email; Postgres uses NULL so the unique
    // index permits many. Duplicate real emails also collapse to NULL, since
    // Mongo's partial index would have rejected them but old data may predate it.
    const seenEmail = new Set();
    for (const d of docs) {
      const legacyId = oid(d._id);
      const existingId = userIds.get(legacyId);
      if (existingId && !REFRESH) { skipped++; continue; }

      let email = str(d.email).trim().toLowerCase() || null;
      if (email && seenEmail.has(email)) {
        console.warn(`  ! duplicate email "${email}" on ${d.username} — storing NULL`);
        email = null;
      }
      if (email) seenEmail.add(email);

      if (!COMMIT) {
        // Record a placeholder so dependent tables can still be checked for
        // dangling references during a dry run.
        userIds.set(legacyId, `dry-run:${legacyId}`);
        written++;
        continue;
      }
      const data = {
        legacyId,
        username: str(d.username),
        contactNumber: str(d.contactNumber),
        email,
        password: str(d.password), // already a bcrypt hash — copied verbatim
        isVerified: Boolean(d.isVerified),
        avatar: str(d.avatar),
        // Portal-side fields (inline OTP + mirrored verification state)
        otp: d.otp ? str(d.otp) : null,
        otpExpires: date(d.otpExpires),
        otpType: d.otpType ? str(d.otpType) : null,
        verificationStatus: d.verificationStatus ? str(d.verificationStatus) : null,
        verificationStep:
          d.verificationStep === null || d.verificationStep === undefined
            ? null
            : int(d.verificationStep, null),
        isPwd: Boolean(d.isPwd),
        isSenior: Boolean(d.isSenior),
        isIndigent: Boolean(d.isIndigent),
        createdAt: date(d.createdAt) || new Date(),
        updatedAt: date(d.updatedAt) || new Date(),
      };

      try {
        const row = existingId
          ? await prisma.user.update({ where: { id: existingId }, data })
          : await prisma.user.create({ data });
        userIds.set(legacyId, row.id);
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x user ${legacyId} (${d.username}): ${e.message.split('\n')[0]}`);
      }
    }
    report('users', { read: docs.length, written, skipped, failed });
  }

  // ── admins ──────────────────────────────────────────────────────────────────
  // The `admins` collection is owned by the admin portal (irq-admin), whose
  // models/User.js defines it: fullName / purok / email / role, no username.
  console.log('admins');
  const adminIds = new Map();
  for (const a of await prisma.admin.findMany({ select: { id: true, legacyId: true } })) {
    if (a.legacyId) adminIds.set(a.legacyId, a.id);
  }
  {
    const docs = await readAll(db, 'admins');
    let written = 0, skipped = 0, failed = 0;
    for (const d of docs) {
      const legacyId = oid(d._id);
      if (adminIds.has(legacyId)) { skipped++; continue; }

      const email = str(d.email).trim().toLowerCase();
      if (!email) {
        failed++;
        console.warn(`  x admin ${legacyId}: no email (required, and the unique key)`);
        continue;
      }
      if (!COMMIT) { adminIds.set(legacyId, `dry-run:${legacyId}`); written++; continue; }
      try {
        const row = await prisma.admin.create({
          data: {
            legacyId,
            fullName: str(d.fullName).trim(),
            purok: str(d.purok),
            email,
            password: d.password ? str(d.password) : null,
            role: pick(
              d.role,
              ['Secretary', 'Collector', 'Barangay Captain', 'Purok Leader'],
              'Secretary'
            ),
            oauthProvider: d.oauthProvider ? str(d.oauthProvider) : null,
            oauthId: d.oauthId ? str(d.oauthId) : null,
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
        });
        adminIds.set(legacyId, row.id);
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x admin ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('admins', { read: docs.length, written, skipped, failed });
  }

  // ── verification profiles ───────────────────────────────────────────────────
  console.log('verification_profiles');
  {
    const docs = await readAll(db, 'verificationprofiles');
    let written = 0, skipped = 0, failed = 0;
    const existing = new Map(
      (await prisma.verificationProfile.findMany({ select: { id: true, legacyId: true } }))
        .map((p) => [p.legacyId, p.id])
    );
    for (const d of docs) {
      const legacyId = oid(d._id);
      const existingId = existing.get(legacyId);
      if (existingId && !REFRESH) { skipped++; continue; }

      const userId = userIds.get(oid(d.user));
      if (!userId) {
        failed++;
        console.warn(`  x profile ${legacyId}: no user for ${oid(d.user)}`);
        continue;
      }
      if (!COMMIT) { written++; continue; }
      try {
        await upsertProfile(existingId, {
            legacyId,
            userId,
            fullName: str(d.fullName),
            address: str(d.address),
            birthday: date(d.birthday),
            age: d.age === null || d.age === undefined ? null : int(d.age, null),
            gender: str(d.gender),
            indigent: str(d.indigent),
            yearsOfResidency: str(d.yearsOfResidency),
            // Almost every row uses the portal's numeric yearsAtAddress.
            yearsAtAddress:
              d.yearsAtAddress === null || d.yearsAtAddress === undefined
                ? null
                : int(d.yearsAtAddress, null),
            motherName: str(d.motherName),
            fatherName: str(d.fatherName),
            isPwd: Boolean(d.isPwd),
            isSenior: Boolean(d.isSenior),
            isIndigent: Boolean(d.isIndigent),
            civilStatus: d.civilStatus ? str(d.civilStatus) : null,
            nationality: d.nationality ? str(d.nationality) : null,
            contactNumber: d.contactNumber ? str(d.contactNumber) : null,
            email: d.email ? str(d.email).toLowerCase() : null,
            freeProofDocument: str(d.freeProofDocument),
            pwdProof: d.pwdProof ? str(d.pwdProof) : null,
            indigentProof: d.indigentProof ? str(d.indigentProof) : null,
            governmentId: d.governmentId ? str(d.governmentId) : null,
            selfieWithId: d.selfieWithId ? str(d.selfieWithId) : null,
            proofOfResidency: d.proofOfResidency ? str(d.proofOfResidency) : null,
            secondaryIdType: d.secondaryIdType ? str(d.secondaryIdType) : null,
            secondaryIdName: d.secondaryIdName ? str(d.secondaryIdName) : null,
            secondaryIdFront: d.secondaryIdFront ? str(d.secondaryIdFront) : null,
            secondaryId2Type: d.secondaryId2Type ? str(d.secondaryId2Type) : null,
            secondaryId2Name: d.secondaryId2Name ? str(d.secondaryId2Name) : null,
            secondaryId2Front: d.secondaryId2Front ? str(d.secondaryId2Front) : null,
            remarks: str(d.remarks),
            reviewedById: adminIds.get(oid(d.reviewedBy)) || null,
            aiVerification: d.aiVerification
              ? JSON.parse(JSON.stringify(d.aiVerification))
              : undefined,
            educationLevel: str(d.educationLevel),
            school: str(d.school),
            yearGraduated: str(d.yearGraduated),
            course: str(d.course),
            educationCertificate: str(d.educationCertificate),
            idType: str(d.idType),
            idName: str(d.idName),
            idFront: str(d.idFront),
            idBack: str(d.idBack),
            facePhoto: str(d.facePhoto),
            idName2: str(d.idName2),
            idFront2: str(d.idFront2),
            idBack2: str(d.idBack2),
            currentStep: int(d.currentStep, 1),
            // Free-form: the portal writes 'submitted' / 'under review' /
            // 'Pending' alongside the Flutter backend's four values.
            status: str(d.status, 'draft'),
            rejectionReason: str(d.rejectionReason),
            submittedAt: date(d.submittedAt),
            reviewedAt: date(d.reviewedAt),
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x profile ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('verification_profiles', { read: docs.length, written, skipped, failed });
  }

  // ── requests ────────────────────────────────────────────────────────────────
  console.log('requests');
  {
    const docs = await readAll(db, 'requests');
    let written = 0, skipped = 0, failed = 0;
    // orNumber is unique; blank out any duplicate rather than losing the row.
    const seenOr = new Set(
      (await prisma.request.findMany({ where: { orNumber: { not: null } }, select: { orNumber: true } }))
        .map((r) => r.orNumber)
    );
    for (const d of docs) {
      const legacyId = oid(d._id);
      if (requestIds.has(legacyId)) { skipped++; continue; }

      const userId = userIds.get(oid(d.user));
      if (!userId) {
        failed++;
        console.warn(`  x request ${legacyId}: no user for ${oid(d.user)}`);
        continue;
      }

      let orNumber = str(d.orNumber).trim() || null;
      if (orNumber && seenOr.has(orNumber)) {
        console.warn(`  ! duplicate orNumber "${orNumber}" — storing NULL`);
        orNumber = null;
      }
      if (orNumber) seenOr.add(orNumber);

      if (!COMMIT) {
        requestIds.set(legacyId, `dry-run:${legacyId}`);
        written++;
        continue;
      }
      try {
        const row = await prisma.request.create({
          data: {
            legacyId,
            userId,
            documentType: str(d.documentType),
            purpose: str(d.purpose),
            additionalDetails: str(d.additionalDetails),
            deliveryMethod: str(d.deliveryMethod, 'Pick up at Barangay Office'),
            // Free-form: the portal writes 'Completed'/'Claimed' alongside the
            // Flutter backend's four values. Copied verbatim rather than mapped.
            status: str(d.status, 'Pending'),
            paymentStatus: str(d.paymentStatus, 'unpaid'),
            paymentSessionId: d.paymentSessionId ? str(d.paymentSessionId) : null,
            paymentLinkId: d.paymentLinkId ? str(d.paymentLinkId) : null,
            amountPaid: dec(d.amountPaid),
            orNumber,
            freeDocumentProof: str(d.freeDocumentProof),
            requestPhoto: str(d.requestPhoto),
            controlNumber: str(d.controlNumber),
            purokLeaderStatus: pick(d.purokLeaderStatus, ['pending', 'approved', 'rejected'], 'pending'),
            purokLeaderApprovedAt: date(d.purokLeaderApprovedAt),
            // Portal-side approval fields
            purokLeaderAt: date(d.purokLeaderAt),
            purokLeaderBy: adminIds.get(oid(d.purokLeaderBy)) || null,
            purokLeaderRemarks: str(d.purokLeaderRemarks),
            claimCode: d.claimCode ? str(d.claimCode) : null,
            yearsAtAddress:
              d.yearsAtAddress === null || d.yearsAtAddress === undefined
                ? null
                : int(d.yearsAtAddress, null),
            purokClearanceFee: dec(d.purokClearanceFee),
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
        });
        requestIds.set(legacyId, row.id);
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x request ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('requests', { read: docs.length, written, skipped, failed });
  }

  // ── completed documents ─────────────────────────────────────────────────────
  console.log('completed_documents');
  {
    const docs = await readAll(db, 'completed_documents');
    let written = 0, skipped = 0, failed = 0;
    const existing = new Set(
      (await prisma.completedDocument.findMany({ select: { legacyId: true } })).map((c) => c.legacyId)
    );
    // The Mongoose schema was strict:false, so anything outside the known
    // fields is preserved in `metadata` rather than dropped.
    const KNOWN = new Set([
      '_id', 'user', 'userId', 'requestId', 'request', 'documentType', 'claimCode',
      'claimStatus', 'completedAt', 'createdAt', 'updatedAt', '__v',
      // snapshot fields the admin portal writes — now real columns
      'purpose', 'fullName', 'age', 'purok', 'address',
    ]);
    for (const d of docs) {
      const legacyId = oid(d._id);
      if (existing.has(legacyId)) { skipped++; continue; }

      // `user` was an ObjectId ref, `userId` a string fallback — try both.
      const userId = userIds.get(oid(d.user)) || userIds.get(str(d.userId)) || null;
      // The Flutter backend called it requestId; the portal calls it request.
      const requestId =
        requestIds.get(oid(d.requestId)) || requestIds.get(oid(d.request)) || null;

      const extras = {};
      for (const [k, v] of Object.entries(d)) if (!KNOWN.has(k)) extras[k] = v;

      if (!COMMIT) { written++; continue; }
      try {
        await prisma.completedDocument.create({
          data: {
            legacyId,
            userId,
            requestId,
            documentType: d.documentType ? str(d.documentType) : null,
            claimCode: d.claimCode ? str(d.claimCode) : null,
            claimStatus: d.claimStatus ? str(d.claimStatus) : null,
            completedAt: date(d.completedAt),
            purpose: d.purpose ? str(d.purpose) : null,
            fullName: d.fullName ? str(d.fullName) : null,
            age: d.age === null || d.age === undefined ? null : int(d.age, null),
            purok: d.purok ? str(d.purok) : null,
            address: d.address ? str(d.address) : null,
            metadata: Object.keys(extras).length ? JSON.parse(JSON.stringify(extras)) : undefined,
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x completed_doc ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('completed_documents', { read: docs.length, written, skipped, failed });
  }

  // ── document prices ─────────────────────────────────────────────────────────
  console.log('document_prices');
  {
    const docs = await readAll(db, 'documentprices');
    let written = 0, skipped = 0, failed = 0;
    for (const d of docs) {
      const documentType = str(d.documentType).trim();
      if (!documentType) { failed++; continue; }
      if (!COMMIT) { written++; continue; }
      try {
        // upsert on the natural key so a re-run refreshes rather than duplicates
        await prisma.documentPrice.upsert({
          where: { documentType },
          create: {
            legacyId: oid(d._id),
            documentType,
            pricecentavos: int(d.pricecentavos),
            description: str(d.description),
            updatedBy: str(d.updatedBy),
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
          update: {
            pricecentavos: int(d.pricecentavos),
            description: str(d.description),
            updatedBy: str(d.updatedBy),
          },
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x price ${documentType}: ${e.message.split('\n')[0]}`);
      }
    }
    report('document_prices', { read: docs.length, written, skipped, failed });
  }

  // ── purok clearance fee ─────────────────────────────────────────────────────
  console.log('purok_clearance_fee');
  {
    const docs = await readAll(db, 'purok_clearance_fee');
    let written = 0, skipped = 0, failed = 0;
    for (const d of docs) {
      const purokName = str(d.purokName).trim();
      if (!purokName) { failed++; continue; }
      if (!COMMIT) { written++; continue; }
      try {
        await prisma.purokClearanceFee.upsert({
          where: { purokName },
          create: {
            legacyId: oid(d._id),
            purokName,
            feecentavos: int(d.feecentavos),
            treasurerName: str(d.treasurerName),
            purokPresident: str(d.purokPresident),
            description: str(d.description),
            updatedBy: str(d.updatedBy),
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
          update: {
            feecentavos: int(d.feecentavos),
            treasurerName: str(d.treasurerName),
            purokPresident: str(d.purokPresident),
            description: str(d.description),
            updatedBy: str(d.updatedBy),
          },
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x purok fee ${purokName}: ${e.message.split('\n')[0]}`);
      }
    }
    report('purok_clearance_fee', { read: docs.length, written, skipped, failed });
  }

  // ── counters (OR number sequences) ──────────────────────────────────────────
  console.log('counters');
  {
    const docs = await readAll(db, 'counters');
    let written = 0, skipped = 0, failed = 0;
    for (const d of docs) {
      const id = str(d._id);
      if (!id) { failed++; continue; }
      if (!COMMIT) { written++; continue; }
      try {
        await prisma.counter.upsert({
          where: { id },
          create: { id, seq: int(d.seq) },
          update: { seq: int(d.seq) },
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x counter ${id}: ${e.message.split('\n')[0]}`);
      }
    }
    report('counters', { read: docs.length, written, skipped, failed });
  }

  // ── documents (staff-entered walk-in requests) ──────────────────────────────
  console.log('documents');
  const documentIds = new Map();
  for (const d of await prisma.document.findMany({ select: { id: true, legacyId: true } })) {
    if (d.legacyId) documentIds.set(d.legacyId, d.id);
  }
  {
    const docs = await readAll(db, 'documents');
    let written = 0, skipped = 0, failed = 0;
    const seenCustom = new Set(
      (await prisma.document.findMany({ where: { customId: { not: null } }, select: { customId: true } }))
        .map((x) => x.customId)
    );
    for (const d of docs) {
      const legacyId = oid(d._id);
      if (documentIds.has(legacyId)) { skipped++; continue; }

      let customId = str(d.customId).trim() || null;
      if (customId && seenCustom.has(customId)) {
        console.warn(`  ! duplicate customId "${customId}" — storing NULL`);
        customId = null;
      }
      if (customId) seenCustom.add(customId);

      if (!COMMIT) { documentIds.set(legacyId, `dry-run:${legacyId}`); written++; continue; }
      try {
        const row = await prisma.document.create({
          data: {
            legacyId,
            customId,
            createdById: adminIds.get(oid(d.createdBy)) || null,
            fullName: str(d.fullName),
            age: d.age === null || d.age === undefined ? null : int(d.age, null),
            gender: d.gender ? str(d.gender) : null,
            dateOfBirth: date(d.dateOfBirth),
            maritalStatus: d.maritalStatus ? str(d.maritalStatus) : null,
            purok: d.purok ? str(d.purok) : null,
            contactNumber: d.contactNumber ? str(d.contactNumber) : null,
            email: d.email ? str(d.email) : null,
            residentType: pick(d.residentType, ['Regular', 'PWD', 'Senior Citizen', 'IP'], 'Regular'),
            ipMember: Boolean(d.ipMember),
            ethnicGroup: d.ethnicGroup ? str(d.ethnicGroup) : null,
            registeredVoter: Boolean(d.registeredVoter),
            documentType: str(d.documentType),
            requestDate: date(d.requestDate) || new Date(),
            purpose: d.purpose ? str(d.purpose) : null,
            status: pick(d.status, ['Pending', 'Processing', 'Printing', 'Completed', 'Rejected'], 'Pending'),
            paymentStatus: pick(d.paymentStatus, ['Pending', 'Pending Verification', 'Paid', 'Exempt'], 'Pending'),
            documentFee: dec(d.documentFee, 130),
            receiptFile: d.receiptFile ? str(d.receiptFile) : null,
            orNumber: d.orNumber ? str(d.orNumber) : null,
            signatureStatus: str(d.signatureStatus),
            sealStatus: str(d.sealStatus),
            residentPhoto: d.residentPhoto ? str(d.residentPhoto) : null,
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
        });
        documentIds.set(legacyId, row.id);
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x document ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('documents', { read: docs.length, written, skipped, failed });
  }

  // ── payments ────────────────────────────────────────────────────────────────
  console.log('payments');
  {
    const docs = await readAll(db, 'payments');
    let written = 0, skipped = 0, failed = 0;
    const existing = new Set(
      (await prisma.payment.findMany({ select: { legacyId: true } })).map((p) => p.legacyId)
    );
    for (const d of docs) {
      const legacyId = oid(d._id);
      if (existing.has(legacyId)) { skipped++; continue; }

      // The model says ref 'User' (admins), but every row points at a resident.
      const userId = userIds.get(oid(d.user));
      if (!userId) {
        failed++;
        console.warn(`  x payment ${legacyId}: no resident for ${oid(d.user)}`);
        continue;
      }

      // Request links are kept as legacy ids too: existing rows reference
      // requests that have since been deleted and would otherwise be lost.
      const legacyRequestIds = Array.isArray(d.requests) ? d.requests.map(oid).filter(Boolean) : [];
      const liveRequestIds = legacyRequestIds
        .map((r) => requestIds.get(r))
        .filter((r) => r && !String(r).startsWith('dry-run:'));

      if (!COMMIT) { written++; continue; }
      try {
        await prisma.payment.create({
          data: {
            legacyId,
            userId,
            documentId: documentIds.get(oid(d.document)) || null,
            documentType: d.documentType ? str(d.documentType) : null,
            amount: dec(d.amount),
            provider: pick(d.provider, ['paymongo', 'stripe', 'gcash', 'manual'], 'manual'),
            sessionId: d.sessionId ? str(d.sessionId) : null,
            paymentId: d.paymentId ? str(d.paymentId) : null,
            status: pick(d.status, ['pending', 'paid', 'failed'], 'pending'),
            legacyRequestIds,
            requests: liveRequestIds.length
              ? { connect: liveRequestIds.map((id) => ({ id })) }
              : undefined,
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x payment ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('payments', { read: docs.length, written, skipped, failed });
  }

  // ── audit trails ────────────────────────────────────────────────────────────
  console.log('audit_trails');
  {
    const docs = await readAll(db, 'audittrails');
    let written = 0, skipped = 0, failed = 0;
    const existing = new Set(
      (await prisma.auditTrail.findMany({ select: { legacyId: true } })).map((a) => a.legacyId)
    );
    for (const d of docs) {
      const legacyId = oid(d._id);
      if (existing.has(legacyId)) { skipped++; continue; }
      if (!COMMIT) { written++; continue; }
      try {
        await prisma.auditTrail.create({
          data: {
            legacyId,
            // nullable: the log outlives the admin it refers to
            adminId: adminIds.get(oid(d.user)) || null,
            username: d.username ? str(d.username) : null,
            role: d.role ? str(d.role) : null,
            action: str(d.action),
            details: d.details ? str(d.details) : null,
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x audit ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('audit_trails', { read: docs.length, written, skipped, failed });
  }

  // ── notifications ───────────────────────────────────────────────────────────
  console.log('notifications');
  {
    const docs = await readAll(db, 'notifications');
    let written = 0, skipped = 0, failed = 0;
    const existing = new Set(
      (await prisma.notification.findMany({ select: { legacyId: true } })).map((n) => n.legacyId)
    );
    for (const d of docs) {
      const legacyId = oid(d._id);
      if (existing.has(legacyId)) { skipped++; continue; }

      const adminId = adminIds.get(oid(d.user));
      if (!adminId) {
        failed++;
        console.warn(`  x notification ${legacyId}: no admin for ${oid(d.user)}`);
        continue;
      }
      if (!COMMIT) { written++; continue; }
      try {
        await prisma.notification.create({
          data: {
            legacyId,
            adminId,
            message: str(d.message),
            status: pick(d.status, ['Unread', 'Read'], 'Unread'),
            createdAt: date(d.createdAt) || new Date(),
            updatedAt: date(d.updatedAt) || new Date(),
          },
        });
        written++;
      } catch (e) {
        failed++;
        console.warn(`  x notification ${legacyId}: ${e.message.split('\n')[0]}`);
      }
    }
    report('notifications', { read: docs.length, written, skipped, failed });
  }

  // OTPs are deliberately not migrated: they expire in 10 minutes and Mongo's
  // TTL index has almost certainly cleared them already. Anyone mid-verification
  // during the cutover just requests a new code.
  console.log('otp_codes — skipped by design (short-lived)\n');

  // ── summary ─────────────────────────────────────────────────────────────────
  const pad = (s, n) => String(s).padEnd(n);
  const padL = (s, n) => String(s).padStart(n);
  console.log('─'.repeat(62));
  console.log(`${pad('table', 24)}${padL('read', 8)}${padL('written', 9)}${padL('skipped', 9)}${padL('failed', 8)}`);
  console.log('─'.repeat(62));
  let totalFailed = 0;
  for (const s of stats) {
    totalFailed += s.failed;
    console.log(`${pad(s.table, 24)}${padL(s.read, 8)}${padL(s.written, 9)}${padL(s.skipped, 9)}${padL(s.failed, 8)}`);
  }
  console.log('─'.repeat(62));

  if (!COMMIT) {
    console.log('\nDRY RUN — nothing was written. Re-run with --commit to apply.');
  } else if (totalFailed > 0) {
    console.log(`\nDone, but ${totalFailed} row(s) failed. See the warnings above.`);
  } else {
    console.log('\nDone — all rows migrated.');
  }

  await prisma.$disconnect();
  await mongoose.disconnect();
}

main().catch(async (e) => {
  console.error('\nMIGRATION FAILED:', e.message);
  try { await prisma.$disconnect(); } catch {}
  try { await mongoose.disconnect(); } catch {}
  process.exit(1);
});
