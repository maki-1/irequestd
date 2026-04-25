const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const Request = require('../models/Request');
const CompletedDocument = require('../models/CompletedDocument');

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
router.post('/', async (req, res) => {
  try {
    const { documentType, purpose, additionalDetails, deliveryMethod } = req.body;
    if (!documentType || !purpose || !deliveryMethod) {
      return res.status(400).json({ message: 'Document type, purpose, and delivery method are required' });
    }
    const request = await Request.create({
      user: req.user.id,
      documentType,
      purpose,
      additionalDetails: additionalDetails || '',
      deliveryMethod,
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
