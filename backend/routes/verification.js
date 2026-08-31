const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const prisma = require('../lib/prisma');
const { uploadIdDoc, uploadFace, uploadFreeProof } = require('../config/cloudinary');

router.use(authMiddleware);

// Mongo's findOneAndUpdate with { new: true } returned null when no document
// matched; Prisma's update throws P2025 instead. This keeps the old shape so
// the "complete the previous step first" branches still work.
const updateProfile = (userId, data) =>
  prisma.verificationProfile.update({ where: { userId }, data }).catch((e) => {
    if (e.code === 'P2025') return null;
    throw e;
  });

// ── GET /api/verification/status ─────────────────────────────────────────────
router.get('/status', async (req, res) => {
  try {
    const profile = await prisma.verificationProfile.findUnique({
      where: { userId: req.user.id },
    });
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
router.post('/step1', uploadFreeProof.single('freeDocumentProof'), async (req, res) => {
  try {
    const { fullName, address, birthday, sex, indigent, yearsOfResidency, motherName, fatherName, isPwd } =
      req.body;

    if (!fullName || !address || !birthday || !sex || !indigent || !yearsOfResidency || !motherName || !fatherName) {
      return res.status(400).json({ message: 'All fields are required' });
    }

    const parsedBirthday = new Date(birthday);
    if (isNaN(parsedBirthday.getTime())) {
      return res.status(400).json({ message: 'Invalid birthday date' });
    }

    const today = new Date();
    let age = today.getFullYear() - parsedBirthday.getFullYear();
    const monthDiff = today.getMonth() - parsedBirthday.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < parsedBirthday.getDate())) {
      age--;
    }

    const updateData = {
      fullName: fullName.trim(),
      address: address.trim(),
      birthday: parsedBirthday,
      age,
      gender: sex.trim(),
      indigent: indigent.trim(),
      yearsOfResidency,
      motherName: motherName.trim(),
      fatherName: fatherName.trim(),
      isPwd: isPwd === true || isPwd === 'true',
      currentStep: 2,
    };

    if (req.file) updateData.freeProofDocument = req.file.path;

    const profile = await prisma.verificationProfile.upsert({
      where: { userId: req.user.id },
      create: { userId: req.user.id, ...updateData },
      update: updateData,
    });

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

      const profile = await updateProfile(req.user.id, updateData);

      if (!profile) return res.status(400).json({ message: 'Complete Step 1 first' });

      res.json({ message: 'Step 2 saved', currentStep: profile.currentStep });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error' });
    }
  });
});

// IDs that have no back side — back upload is optional for these
const SINGLE_PAGE_IDS = new Set([
  'Philippine Passport',
  'NBI Clearance',
  'Police Clearance',
  'PSA Birth Certificate',
  'Marriage Certificate',
]);

// ── POST /api/verification/step3 ─────────────────────────────────────────────
const step3Upload = uploadIdDoc.fields([
  { name: 'facePhoto', maxCount: 1 },
  { name: 'idFront',   maxCount: 1 },
  { name: 'idBack',    maxCount: 1 },
  { name: 'idFront2',  maxCount: 1 },
  { name: 'idBack2',   maxCount: 1 },
]);

router.post('/step3', (req, res) => {
  step3Upload(req, res, async (err) => {
    if (err) return res.status(400).json({ message: err.message });

    try {
      const { idType, idName, idName2 } = req.body;
      const files = req.files || {};

      if (!idType || !idName) {
        return res.status(400).json({ message: 'ID type and ID name are required' });
      }
      if (!files.idFront) {
        return res.status(400).json({ message: 'Front of ID is required' });
      }
      // Back is only required for IDs that have a back side
      if (!SINGLE_PAGE_IDS.has(idName) && !files.idBack) {
        return res.status(400).json({ message: 'Back of ID is required' });
      }

      const updateFields = {
        idType,
        idName,
        idFront: files.idFront[0].path,
        currentStep: 3,
        status: 'pending',
        submittedAt: new Date(),
      };

      if (files.idBack)    updateFields.idBack    = files.idBack[0].path;
      if (files.facePhoto) updateFields.facePhoto = files.facePhoto[0].path;

      // Second ID (secondary type only)
      if (idName2) updateFields.idName2 = idName2;
      if (files.idFront2) updateFields.idFront2 = files.idFront2[0].path;
      if (files.idBack2)  updateFields.idBack2  = files.idBack2[0].path;

      const profile = await updateProfile(req.user.id, updateFields);

      if (!profile) return res.status(400).json({ message: 'Complete previous steps first' });

      res.json({ message: 'Verification submitted successfully', status: 'pending' });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: 'Server error' });
    }
  });
});

module.exports = router;
