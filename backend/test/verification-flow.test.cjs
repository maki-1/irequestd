// Exercise real routes/auth with an isolated DB and in-memory file storage.
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const multer = require('multer');
const { signToken } = require('../lib/accountLifecycle');
const uid = '11111111-1111-4111-8111-111111111111';
const user = { id: uid, active: true, deletedAt: null, sessionVersion: 0, contactVerified: true };
let profile, server, base;
const copy = (value) => structuredClone(value);
function stub(file, exports) {
  const id = require.resolve(file);
  require.cache[id] = { id, filename: id, loaded: true, exports };
}
stub('../lib/prisma', {
  user: { findUnique: async ({ where }) => where.id === uid ? copy(user) : null },
  purokClearanceFee: { findMany: async () => [{ purokName: 'Purok 1', feecentavos: 2000 }] },
  verificationProfile: {
    findUnique: async () => copy(profile),
    upsert: async ({ create, update }) => {
      profile = profile ? { ...profile, ...copy(update) } : { status: 'draft', submittedAt: null, ...copy(create) };
      return copy(profile);
    },
    update: async ({ data }) => {
      if (!profile) throw Object.assign(new Error('Missing profile'), { code: 'P2025' });
      Object.assign(profile, copy(data)); return copy(profile);
    },
  },
});
const upload = multer({ storage: {
  _handleFile(req, file, cb) {
    file.stream.resume();
    file.stream.on('end', () => cb(null, { path: `https://media.example.test/${file.fieldname}.jpg` }));
  },
  _removeFile(req, file, cb) { cb(null); },
} });
stub('../config/cloudinary', { uploadIdDoc: upload, uploadFace: upload, uploadFreeProof: upload });
const app = express(); app.use(express.json());
app.use('/api/verification', require('../routes/verification'));
before(async () => {
  process.env.JWT_SECRET = 'isolated-mobile-verification-test';
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/verification`;
});
after(async () => { if (server) await new Promise((resolve) => server.close(resolve)); });
beforeEach(() => { profile = null; });
async function post(path, body = {}, authenticated = true) {
  const multipart = body instanceof FormData;
  const response = await fetch(base + path, { method: 'POST', headers: {
    ...(authenticated ? { Authorization: `Bearer ${signToken(user, 'resident')}` } : {}),
    ...(multipart ? {} : { 'Content-Type': 'application/json' }),
  }, body: multipart ? body : JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
}
const personal = { fullName: 'QA Resident', address: 'Purok 1, Dologon', purok: 'Purok 1', birthday: '2000-01-01', sex: 'Female', indigent: 'No', yearsOfResidency: '5' };

test('personal information without parents or education can proceed straight to ID and face submission', async () => {
  const form = new FormData();
  for (const [key, value] of Object.entries(personal)) form.set(key, value);
  const result = await post('/step1', form);
  assert.equal(result.status, 200, JSON.stringify(result));
  assert.equal(profile.currentStep, 3); // persisted legacy ID stage
  assert.equal(profile.status, 'draft'); assert.equal(profile.submittedAt, null);
  assert.equal(profile.motherName, undefined); assert.equal(profile.fatherName, undefined);
  assert.equal(profile.educationLevel, undefined);
  const identity = new FormData();
  identity.set('idType', 'primary'); identity.set('idName', 'Philippine Passport');
  identity.set('idFront', new Blob(['synthetic ID'], { type: 'image/jpeg' }), 'id.jpg');
  identity.set('facePhoto', new Blob(['synthetic selfie'], { type: 'image/jpeg' }), 'face.jpg');
  assert.equal((await post('/step3', identity)).status, 200);
  assert.equal(profile.status, 'pending'); assert.ok(profile.submittedAt);
  assert.equal(profile.facePhoto, 'https://media.example.test/facePhoto.jpg');
});

test('removed fields sent by older apps cannot overwrite historical values', async () => {
  profile = { userId: uid, status: 'draft', currentStep: 2, motherName: 'Historical Mother', fatherName: 'Historical Father', school: 'Historical School' };
  assert.equal((await post('/step1', { ...personal, motherName: 'Ignored', fatherName: 'Ignored' })).status, 200);
  assert.equal(profile.motherName, 'Historical Mother'); assert.equal(profile.fatherName, 'Historical Father');
  const saved = copy(profile);
  const legacy = new FormData();
  legacy.set('educationLevel', 'College');
  legacy.set('educationCertificate', new Blob(['unused'], { type: 'image/jpeg' }), 'education.jpg');
  assert.equal((await post('/step2', legacy)).status, 200);
  assert.deepEqual(profile, saved);
});

test('legacy education endpoint cannot create a profile or submit one for review', async () => {
  assert.equal((await post('/step2')).status, 400); assert.equal(profile, null);
  await post('/step1', personal);
  const saved = copy(profile);
  assert.equal((await post('/step2')).status, 200); assert.deepEqual(profile, saved);
});

test('required personal information and identity documents are still enforced', async () => {
  for (const field of ['fullName', 'address', 'birthday', 'sex', 'purok']) {
    assert.equal((await post('/step1', { ...personal, [field]: '' })).status, 400);
    assert.equal(profile, null);
  }
  await post('/step1', personal);
  assert.equal((await post('/step3', { idType: 'primary', idName: 'Philippine Passport' })).status, 400);
  assert.equal(profile.status, 'draft');
});

test('verification endpoints still require authentication', async () => {
  for (const path of ['/step1', '/step2', '/step3']) assert.equal((await post(path, {}, false)).status, 401);
  assert.equal(profile, null);
});
