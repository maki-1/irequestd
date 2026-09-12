const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const prisma = require('../lib/prisma');
const { nextOrNumber } = require('../lib/orNumber');
const { toApi } = require('../lib/serialize');
const { isUuid } = require('../lib/ids');
const { notifyPurokLeader } = require('../lib/purokNotify');
const { normalizePurpose } = require('../lib/purpose');
const { sendSms } = require('../services/sms');
const { sendEmail } = require('../services/email');

router.use(authMiddleware);

const DOCUMENT_TYPES = [
  'Barangay Clearance',
  'Certificate of Residency',
  'Certificate of Indigency',
];
const DELIVERY_METHODS = ['Pick up at Barangay Office'];

// Mongo generated the OR number in a pre('save') hook; Prisma has no hooks, so
// every create path goes through here instead.
async function createRequest(userId, item, channel = 'mobile') {
  return prisma.request.create({
    data: {
      userId,
      documentType: item.documentType,
      purpose: item.purpose,
      additionalDetails: item.additionalDetails || '',
      deliveryMethod: item.deliveryMethod || 'Pick up at Barangay Office',
      orNumber: await nextOrNumber(),
      channel,
    },
  });
}

// A new request sits at purokLeaderStatus 'pending' and cannot be paid for
// until the Purok Leader approves it — but nothing used to tell them it was
// there. Notification is fired after the response is already on its way, so a
// slow SMS gateway never delays the resident.
function announceToPurokLeader(userId, documentTypes, channel) {
  notifyPurokLeader({ userId, documentTypes, channel, sendSms, sendEmail })
    .then((r) => {
      if (!r.notified) console.warn(`[requests] purok leader not notified: ${r.reason}`);
    })
    .catch((e) => console.error('[requests] notify failed:', e.message));
}

// GET /api/requests
router.get('/', async (req, res) => {
  try {
    const requests = await prisma.request.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    res.json(toApi(requests));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/requests/summary
router.get('/summary', async (req, res) => {
  try {
    const userId = req.user.id;
    const [total, pending, processing, ready, rejected] = await Promise.all([
      prisma.request.count({ where: { userId } }),
      prisma.request.count({ where: { userId, status: 'Pending' } }),
      prisma.request.count({ where: { userId, status: 'Processing' } }),
      prisma.request.count({ where: { userId, status: 'Ready' } }),
      prisma.request.count({ where: { userId, status: 'Rejected' } }),
    ]);
    res.json({ total, pending, processing, ready, rejected });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// POST /api/requests
router.post('/', async (req, res) => {
  try {
    const { documentType, purpose, additionalDetails, deliveryMethod } = req.body;
    if (!documentType || !purpose || !deliveryMethod) {
      return res.status(400).json({ message: 'Document type, purpose, and delivery method are required' });
    }
    // Mongoose enforced these through schema enums; validated here instead.
    if (!DOCUMENT_TYPES.includes(documentType)) {
      return res.status(400).json({ message: 'Invalid document type' });
    }
    if (!DELIVERY_METHODS.includes(deliveryMethod)) {
      return res.status(400).json({ message: 'Invalid delivery method' });
    }
    // "Other" is only accepted with the resident's own 1-2 word purpose.
    const checkedPurpose = normalizePurpose(purpose);
    if (!checkedPurpose.ok) {
      return res.status(400).json({ message: checkedPurpose.message });
    }

    const request = await createRequest(req.user.id, {
      documentType, purpose: checkedPurpose.value, additionalDetails, deliveryMethod,
    }, req.body.channel === 'kiosk' ? 'kiosk' : 'mobile');

    res.status(201).json(toApi(request));
    announceToPurokLeader(req.user.id, [documentType], request.channel);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/requests/completed
// Returns docs from completed_documents where user matches and claimStatus = 'Pending'
router.get('/completed', async (req, res) => {
  try {
    const docs = await prisma.completedDocument.findMany({
      where: {
        userId: req.user.id,
        // case-insensitive, matching the old /^pending$/i
        claimStatus: { equals: 'pending', mode: 'insensitive' },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json(toApi(docs));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/requests/claimed
// Returns docs where claimStatus is claimed/complete/completed (already picked up)
router.get('/claimed', async (req, res) => {
  try {
    const docs = await prisma.completedDocument.findMany({
      where: {
        userId: req.user.id,
        // was /^(claimed|complete|completed)$/i
        OR: [
          { claimStatus: { equals: 'claimed', mode: 'insensitive' } },
          { claimStatus: { equals: 'complete', mode: 'insensitive' } },
          { claimStatus: { equals: 'completed', mode: 'insensitive' } },
        ],
      },
      orderBy: { updatedAt: 'desc' },
    });
    res.json(toApi(docs));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// POST /api/requests/bulk  (multi-doc submission)
router.post('/bulk', async (req, res) => {
  try {
    let items;
    try {
      items = typeof req.body.items === 'string' ? JSON.parse(req.body.items) : req.body.items;
    } catch {
      return res.status(400).json({ message: 'Invalid items format' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'At least one document item is required' });
    }
    for (const item of items) {
      if (!DOCUMENT_TYPES.includes(item.documentType)) {
        return res.status(400).json({ message: `Invalid document type: ${item.documentType}` });
      }
      const checkedPurpose = normalizePurpose(item.purpose);
      if (!checkedPurpose.ok) {
        return res.status(400).json({ message: checkedPurpose.message });
      }
      item.purpose = checkedPurpose.value;
    }

    // Sequential rather than parallel: each create draws the next OR number
    // from the shared counter, and serialising keeps them contiguous.
    const channel = req.body.channel === 'kiosk' ? 'kiosk' : 'mobile';
    const requests = [];
    for (const item of items) {
      requests.push(await createRequest(req.user.id, item, channel));
    }

    res.status(201).json(toApi(requests));
    // One notification for the batch, not one per document.
    announceToPurokLeader(req.user.id, requests.map((r) => r.documentType), channel);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// DELETE /api/requests/:id
router.delete('/:id', async (req, res) => {
  try {
    if (!isUuid(req.params.id)) return res.status(404).json({ message: 'Request not found' });

    const { count } = await prisma.request.deleteMany({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (count === 0) return res.status(404).json({ message: 'Request not found' });
    res.json({ message: 'Deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
