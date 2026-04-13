const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const VerificationProfile = require('../models/VerificationProfile');
const { uploadIdDoc, uploadFace } = require('../config/cloudinary');

router.use(authMiddleware);

// ── GET /api/verification/status ─────────────────────────────────────────────
router.get('/status', async (req, res) => {
  try {
    const profile = await VerificationProfile.findOne({ user: req.user.id });
    if (!profile) return res.json({ status: null, currentStep: 1 });
    res.json({
      status: profile.status,
      currentStep: profile.currentStep,
      rejectionReason: profile.rejectionReason,
      submittedAt: profile.submittedAt,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/verification/step1 ──────────────────────────────────────────────
router.post('/step1', async (req, res) => {
  try {
    const { fullName, address, age, gender, yearsAtAddress, motherName, fatherName } =
      req.body;

    if (!fullName || !address || !age || !gender || !yearsAtAddress || !motherName || !fatherName) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    if (parseInt(age) < 18) {
      return res.status(400).json({ message: 'Must be 18 years or older' });
    }

    const profile = await VerificationProfile.findOneAndUpdate(
      { user: req.user.id },
      {
        user: req.user.id,
        fullName: fullName.trim(),
        address: address.trim(),
        age: parseInt(age),
        gender,
        yearsAtAddress,
        motherName: motherName.trim(),
        fatherName: fatherName.trim(),
        currentStep: 2,
      },
      { upsert: true, new: true }
    );

    res.json({ message: 'Step 1 saved', currentStep: profile.currentStep });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/verification/step2 ──────────────────────────────────────────────
const step2Upload = uploadIdDoc.single('educationCertificate');

router.post('/step2', (req, res) => {
  step2Upload(req, res, async (err) => {
    if (err) return res.status(400).json({ message: err.message });

    try {
      const { educationLevel, school, yearGraduated, course } = req.body;

      const updateData = {
        educationLevel: educationLevel || '',
        school: school || '',
        yearGraduated: yearGraduated || '',
        course: course || '',
        currentStep: 3,
        status: 'pending',
        submittedAt: new Date(),
      };

      if (req.file) updateData.educationCertificate = req.file.path;

      const profile = await VerificationProfile.findOneAndUpdate(
        { user: req.user.id },
        updateData,
        { new: true }
      );

      if (!profile) return res.status(400).json({ message: 'Complete Step 1 first' });

      res.json({ message: 'Step 2 saved', currentStep: profile.currentStep });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error' });
    }
  });
});

// ── POST /api/verification/step3 ─────────────────────────────────────────────
const step3Upload = uploadIdDoc.fields([
  { name: 'facePhoto', maxCount: 1 },
  { name: 'idFront', maxCount: 1 },
  { name: 'idBack', maxCount: 1 },
]);

router.post('/step3', (req, res) => {
  step3Upload(req, res, async (err) => {
    if (err) return res.status(400).json({ message: err.message });

    try {
      const { idType, idName } = req.body;
      const files = req.files || {};

      if (!idType || !idName) {
        return res.status(400).json({ message: 'ID type and ID name are required' });
      }
      if (!files.idFront) {
        return res.status(400).json({ message: 'Front of ID is required' });
      }
      if (!files.idBack) {
        return res.status(400).json({ message: 'Back of ID is required' });
      }
      const updateFields = {
        idType,
        idName,
        idFront: files.idFront[0].path,
        idBack: files.idBack[0].path,
        currentStep: 3,
        status: 'pending',
        submittedAt: new Date(),
      };
      if (files.facePhoto) updateFields.facePhoto = files.facePhoto[0].path;

      const profile = await VerificationProfile.findOneAndUpdate(
        { user: req.user.id },
        updateFields,
        { new: true }
      );

      if (!profile) return res.status(400).json({ message: 'Complete previous steps first' });

      res.json({ message: 'Verification submitted successfully', status: 'pending' });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error' });
    }
  });
});

module.exports = router;
