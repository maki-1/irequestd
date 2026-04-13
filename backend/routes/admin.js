const express = require('express');
const router  = express.Router();
const jwt     = require('jsonwebtoken');
const Admin   = require('../models/Admin');
const User    = require('../models/User');
const VerificationProfile = require('../models/VerificationProfile');
const Request = require('../models/Request');

// ── Admin auth middleware ─────────────────────────────────────────────────────
function adminAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer '))
    return res.status(401).json({ message: 'No token' });
  try {
    const decoded = jwt.verify(header.split(' ')[1], process.env.JWT_SECRET);
    if (!decoded.isAdmin) return res.status(403).json({ message: 'Not an admin' });
    req.admin = decoded;
    next();
  } catch {
    res.status(401).json({ message: 'Invalid token' });
  }
}

// ── POST /api/admin/setup  (creates first admin; disabled once one exists) ────
router.post('/setup', async (req, res) => {
  try {
    const count = await Admin.countDocuments();
    if (count > 0)
      return res.status(403).json({ message: 'Setup already completed' });

    const { username, password, name } = req.body;
    if (!username || !password || !name)
      return res.status(400).json({ message: 'username, password and name are required' });

    const admin = await Admin.create({ username, password, name, role: 'superadmin' });
    res.status(201).json({ message: 'Admin created', id: admin._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/admin/login ─────────────────────────────────────────────────────
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const admin = await Admin.findOne({ username });
    if (!admin) return res.status(401).json({ message: 'Invalid credentials' });

    const ok = await admin.comparePassword(password);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });

    const token = jwt.sign(
      { id: admin._id, username: admin.username, name: admin.name, role: admin.role, isAdmin: true },
      process.env.JWT_SECRET,
      { expiresIn: '8h' }
    );
    res.json({ token, name: admin.name, role: admin.role });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── All routes below require admin token ──────────────────────────────────────
router.use(adminAuth);

// ── GET /api/admin/stats ──────────────────────────────────────────────────────
router.get('/stats', async (req, res) => {
  try {
    const [total, pending, approved, rejected, draft, totalRequests] = await Promise.all([
      VerificationProfile.countDocuments(),
      VerificationProfile.countDocuments({ status: 'pending' }),
      VerificationProfile.countDocuments({ status: 'approved' }),
      VerificationProfile.countDocuments({ status: 'rejected' }),
      VerificationProfile.countDocuments({ status: 'draft' }),
      Request.countDocuments(),
    ]);
    res.json({ total, pending, approved, rejected, draft, totalRequests });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/admin/applications ───────────────────────────────────────────────
// Query: status (all|pending|approved|rejected|draft), search, page, limit
router.get('/applications', async (req, res) => {
  try {
    const { status = 'all', search = '', page = 1, limit = 15 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const filter = {};
    if (status !== 'all') filter.status = status;

    let profiles = await VerificationProfile.find(filter)
      .populate('user', 'username email contactNumber isVerified createdAt')
      .sort({ updatedAt: -1 })
      .lean();

    // Client-side search on populated fields
    if (search.trim()) {
      const q = search.trim().toLowerCase();
      profiles = profiles.filter(p =>
        p.fullName?.toLowerCase().includes(q) ||
        p.user?.username?.toLowerCase().includes(q) ||
        p.user?.contactNumber?.includes(q) ||
        p.user?.email?.toLowerCase().includes(q)
      );
    }

    const total = profiles.length;
    const paginated = profiles.slice(skip, skip + parseInt(limit));

    res.json({ applications: paginated, total, page: parseInt(page), limit: parseInt(limit) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/admin/applications/:id ──────────────────────────────────────────
router.get('/applications/:id', async (req, res) => {
  try {
    const profile = await VerificationProfile.findById(req.params.id)
      .populate('user', 'username email contactNumber isVerified createdAt')
      .lean();
    if (!profile) return res.status(404).json({ message: 'Not found' });
    res.json(profile);
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

// ── PUT /api/admin/applications/:id/approve ───────────────────────────────────
router.put('/applications/:id/approve', async (req, res) => {
  try {
    const profile = await VerificationProfile.findByIdAndUpdate(
      req.params.id,
      { status: 'approved', rejectionReason: '', reviewedAt: new Date() },
      { new: true }
    );
    if (!profile) return res.status(404).json({ message: 'Not found' });
    res.json({ message: 'Application approved', status: 'approved' });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

// ── PUT /api/admin/applications/:id/reject ────────────────────────────────────
router.put('/applications/:id/reject', async (req, res) => {
  try {
    const { reason = '' } = req.body;
    const profile = await VerificationProfile.findByIdAndUpdate(
      req.params.id,
      { status: 'rejected', rejectionReason: reason, reviewedAt: new Date() },
      { new: true }
    );
    if (!profile) return res.status(404).json({ message: 'Not found' });
    res.json({ message: 'Application rejected', status: 'rejected' });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

// ── PUT /api/admin/requests/:id/status ────────────────────────────────────────
router.put('/requests/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const allowed = ['Pending', 'Processing', 'Ready', 'Rejected'];
    if (!allowed.includes(status))
      return res.status(400).json({ message: 'Invalid status' });

    const request = await Request.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    );
    if (!request) return res.status(404).json({ message: 'Not found' });
    res.json({ message: 'Status updated', status: request.status });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
