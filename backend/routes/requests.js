const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const Request = require('../models/Request');
const CompletedDocument = require('../models/CompletedDocument');
const VerificationProfile = require('../models/VerificationProfile');
const { uploadFreeProof, uploadRequestPhoto } = require('../config/cloudinary');
const multer = require('multer');
const upload = multer(); // memory-only fallback (unused directly)

router.use(authMiddleware);

// GET /api/requests
router.get('/', async (req, res) => {
  try {
    const requests = await Request.find({ user: req.user.id }).sort({ createdAt: -1 });
    res.json(requests);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/requests/summary
router.get('/summary', async (req, res) => {
  try {
    const [total, pending, processing, ready, rejected] = await Promise.all([
      Request.countDocuments({ user: req.user.id }),
      Request.countDocuments({ user: req.user.id, status: 'Pending' }),
      Request.countDocuments({ user: req.user.id, status: 'Processing' }),
      Request.countDocuments({ user: req.user.id, status: 'Ready' }),
      Request.countDocuments({ user: req.user.id, status: 'Rejected' }),
    ]);
    res.json({ total, pending, processing, ready, rejected });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// POST /api/requests
router.post('/', uploadRequestPhoto.single('requestPhoto'), async (req, res) => {
  try {
    const { documentType, purpose, additionalDetails, deliveryMethod, controlNumber } = req.body;
    if (!documentType || !purpose || !deliveryMethod) {
      return res.status(400).json({ message: 'Document type, purpose, and delivery method are required' });
    }
    if (!controlNumber || !controlNumber.trim()) {
      return res.status(400).json({ message: 'Control number is required' });
    }
    if (!req.file) {
      return res.status(400).json({ message: 'A photo is required for every document request' });
    }

    const request = await Request.create({
      user: req.user.id,
      documentType,
      purpose,
      additionalDetails: additionalDetails || '',
      deliveryMethod,
      controlNumber: controlNumber.trim(),
      requestPhoto: req.file.path,
    });
    res.status(201).json(request);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/requests/completed
// Returns docs from completed_documents where user matches and claimStatus = 'Pending'
router.get('/completed', async (req, res) => {
  try {
    const docs = await CompletedDocument.find({
      $or: [
        { user: req.user.id },
        { userId: req.user.id },
      ],
      claimStatus: /^pending$/i,   // case-insensitive: matches 'pending', 'Pending', etc.
    }).sort({ createdAt: -1 });
    res.json(docs);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/requests/claimed
// Returns docs where claimStatus is claimed/complete/completed (already picked up)
router.get('/claimed', async (req, res) => {
  try {
    const docs = await CompletedDocument.find({
      $or: [
        { user: req.user.id },
        { userId: req.user.id },
      ],
      claimStatus: /^(claimed|complete|completed)$/i,
    }).sort({ updatedAt: -1 });
    res.json(docs);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// POST /api/requests/bulk  (free multi-doc submission)
router.post('/bulk', uploadRequestPhoto.single('requestPhoto'), async (req, res) => {
  try {
    let items;
    try {
      items = JSON.parse(req.body.items || '[]');
    } catch {
      return res.status(400).json({ message: 'Invalid items format' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'At least one document item is required' });
    }
    if (!req.file) {
      return res.status(400).json({ message: 'A photo is required for every document request' });
    }

    const requestPhotoUrl = req.file.path;

    const requests = await Promise.all(items.map((item) =>
      Request.create({
        user: req.user.id,
        documentType: item.documentType,
        purpose: item.purpose,
        additionalDetails: item.additionalDetails || '',
        deliveryMethod: item.deliveryMethod || 'Pick up at Barangay Office',
        controlNumber: (item.controlNumber || '').trim(),
        requestPhoto: requestPhotoUrl,
      })
    ));

    res.status(201).json(requests);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// DELETE /api/requests/:id
router.delete('/:id', async (req, res) => {
  try {
    const request = await Request.findOneAndDelete({ _id: req.params.id, user: req.user.id });
    if (!request) return res.status(404).json({ message: 'Request not found' });
    res.json({ message: 'Deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
