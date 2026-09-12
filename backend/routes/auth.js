const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const prisma = require('../lib/prisma');
const { hashPassword, comparePassword } = require('../lib/password');
const { isUuid } = require('../lib/ids');
const { sendOtp, sendPasswordResetOtp } = require('../services/sms');
const { sendOtpEmail } = require('../services/email');
const { uploadAvatar } = require('../config/cloudinary');

function generateToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN }
  );
}

function generateOtpCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function createAndSendOtp(userId, contactNumber, type) {
  // Invalidate any existing unused OTPs of same type
  await prisma.otpCode.deleteMany({ where: { userId, type, used: false } });

  const code = generateOtpCode();
  const hashed = await hashPassword(code);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

  await prisma.otpCode.create({ data: { userId, code: hashed, type, expiresAt } });

  try {
    if (type === 'reset') {
      await sendPasswordResetOtp(contactNumber, code);
    } else {
      await sendOtp(contactNumber, code);
    }
    console.log(`[OTP] Sent ${type} OTP to ${contactNumber}`);
  } catch (smsErr) {
    // Log the SMS error but don't crash — OTP is saved in DB
    console.error('[OTP] SMS sending failed:', smsErr?.response?.data || smsErr.message);
    console.log(`[OTP] Code for ${contactNumber}: ${code}`); // visible in server logs for testing
  }
}

// ── GET /api/auth/me  (requires token) ───────────────────────────────────────
const authMiddleware = require('../middleware/auth');

router.get('/me', authMiddleware, async (req, res) => {
  try {
    if (!isUuid(req.user.id)) return res.status(404).json({ message: 'User not found' });

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { verificationProfile: true },
    });
    if (!user) return res.status(404).json({ message: 'User not found' });

    const profile = user.verificationProfile;

    res.json({
      id: user.id,
      username: user.username,
      fullName: profile?.fullName || '',
      email: user.email || '',
      contactNumber: user.contactNumber,
      isVerified: user.isVerified,
      avatar: user.avatar || '',
      accountStatus: profile?.status || 'draft',
      verificationStep: profile?.currentStep || 1,
      isPwd: profile?.isPwd || false,
      age: profile?.age ?? null,
      hasFreeProof: !!(profile?.freeProofDocument),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/auth/profile  (requires token) ──────────────────────────────────
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    if (!isUuid(req.user.id)) return res.status(404).json({ message: 'User not found' });

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { verificationProfile: true },
    });
    if (!user) return res.status(404).json({ message: 'User not found' });

    const profile = user.verificationProfile;

    res.json({
      username: user.username,
      email: user.email || '',
      contactNumber: user.contactNumber,
      fullName: profile?.fullName || '',
      age: profile?.age ?? null,
      gender: profile?.gender || '',
      address: profile?.address || '',
      // NOTE: the field on the profile is `yearsOfResidency`; this key has never
      // matched it, so it has always returned ''. Preserved as-is to keep the
      // response identical to the Mongo version — see the migration notes.
      yearsAtAddress: profile?.yearsAtAddress || '',
      motherName: profile?.motherName || '',
      fatherName: profile?.fatherName || '',
      isPwd: profile?.isPwd || false,
      educationLevel: profile?.educationLevel || '',
      school: profile?.school || '',
      yearGraduated: profile?.yearGraduated || '',
      course: profile?.course || '',
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── PUT /api/auth/avatar  (requires token) ───────────────────────────────────
router.put('/avatar', authMiddleware, uploadAvatar.single('avatar'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No image uploaded' });
    if (!isUuid(req.user.id)) return res.status(404).json({ message: 'User not found' });

    // Cloudinary returns the full secure URL in req.file.path
    const user = await prisma.user
      .update({ where: { id: req.user.id }, data: { avatar: req.file.path } })
      .catch(() => null);
    if (!user) return res.status(404).json({ message: 'User not found' });

    res.json({ avatar: req.file.path, message: 'Avatar updated' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── PUT /api/auth/change-password  (requires token) ──────────────────────────
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword, confirmPassword } = req.body;

    if (!currentPassword || !newPassword || !confirmPassword) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    if (newPassword !== confirmPassword) {
      return res.status(400).json({ message: 'New passwords do not match' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters' });
    }
    if (!isUuid(req.user.id)) return res.status(404).json({ message: 'User not found' });

    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user) return res.status(404).json({ message: 'User not found' });

    const match = await comparePassword(currentPassword, user.password);
    if (!match) return res.status(401).json({ message: 'Current password is incorrect' });

    await prisma.user.update({
      where: { id: user.id },
      data: { password: await hashPassword(newPassword) },
    });

    res.json({ message: 'Password changed successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/auth/check-username?username=xxx ─────────────────────────────────
router.get('/check-username', async (req, res) => {
  try {
    const { username } = req.query;
    if (!username) return res.status(400).json({ message: 'Username required' });

    const exists = await prisma.user.findUnique({ where: { username: username.trim() } });
    res.json({ available: !exists });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/auth/check-contact?contact=xxx ───────────────────────────────────
router.get('/check-contact', async (req, res) => {
  try {
    const { contact } = req.query;
    if (!contact) return res.status(400).json({ message: 'Contact required' });

    const digits = contact.replace(/\D/g, '');
    const exists = await prisma.user.findUnique({ where: { contactNumber: digits } });
    res.json({ available: !exists });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── GET /api/auth/check-email?email=xxx ───────────────────────────────────────
router.get('/check-email', async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ message: 'Email required' });

    const exists = await prisma.user.findUnique({ where: { email: email.trim().toLowerCase() } });
    res.json({ available: !exists });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/auth/register ────────────────────────────────────────────────────
router.post('/register', async (req, res) => {
  try {
    const { username, contactNumber, email, password, confirmPassword } = req.body;

    if (!username || !contactNumber || !password || !confirmPassword) {
      return res.status(400).json({ message: 'Please fill in all required fields' });
    }
    if (password !== confirmPassword) {
      return res.status(400).json({ message: 'Passwords do not match' });
    }
    if (password.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters' });
    }

    const digits = contactNumber.replace(/\D/g, '');
    // Empty email is stored as NULL, not '' — the unique index allows many NULLs.
    const normalisedEmail = email ? email.toLowerCase().trim() : null;

    // Check for duplicates before creating
    const [existingUsername, existingContact, existingEmail] = await Promise.all([
      prisma.user.findUnique({ where: { username } }),
      prisma.user.findUnique({ where: { contactNumber: digits } }),
      normalisedEmail ? prisma.user.findUnique({ where: { email: normalisedEmail } }) : null,
    ]);

    if (existingUsername) {
      return res.status(409).json({ message: 'Username already taken' });
    }
    if (existingContact) {
      return res.status(409).json({ message: 'Contact number already registered' });
    }
    if (existingEmail) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    const user = await prisma.user.create({
      data: {
        username,
        contactNumber: digits,
        email: normalisedEmail,
        password: await hashPassword(password),
        isVerified: false,
      },
    });

    await createAndSendOtp(user.id, user.contactNumber, 'register');

    res.status(201).json({
      message: 'OTP sent to your contact number',
      userId: user.id,
      requiresVerification: true,
    });
  } catch (err) {
    // Catch unique-constraint violations as a safety net (was Mongo's 11000)
    if (err.code === 'P2002') {
      const field = err.meta?.target?.[0] || (err.meta?.modelName && '');
      const messages = {
        username: 'Username already taken',
        contactNumber: 'Contact number already registered',
        email: 'Email already registered',
      };
      const key = Object.keys(messages).find((k) => String(field).includes(k));
      return res.status(409).json({ message: messages[key] || 'Duplicate entry' });
    }
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/auth/verify-otp ─────────────────────────────────────────────────
router.post('/verify-otp', async (req, res) => {
  try {
    const { userId, code, type } = req.body;

    if (!userId || !code || !type) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    if (!isUuid(userId)) {
      return res.status(400).json({ message: 'OTP expired or not found. Please request a new one.' });
    }

    const otpRecord = await prisma.otpCode.findFirst({
      where: {
        userId,
        type,
        used: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord) {
      return res.status(400).json({ message: 'OTP expired or not found. Please request a new one.' });
    }

    const match = await comparePassword(code, otpRecord.code);
    if (!match) {
      return res.status(400).json({ message: 'Invalid OTP. Please try again.' });
    }

    // Mark OTP as used
    await prisma.otpCode.update({ where: { id: otpRecord.id }, data: { used: true } });

    if (type === 'register') {
      const user = await prisma.user.update({
        where: { id: userId },
        data: {
          isVerified: true,
          // The admin portal gates its login on this flag, not on isVerified —
          // the two words mean different things there. Set it here so a resident
          // who verified on the app is not asked to verify again on the web.
          contactVerified: true,
          contactVerifiedAt: new Date(),
        },
      });
      const token = generateToken(user);
      return res.json({
        token,
        user: {
          id: user.id,
          username: user.username,
          email: user.email || '',
          contactNumber: user.contactNumber,
          isVerified: true,
          accountStatus: 'draft',
          verificationStep: 1,
        },
      });
    }

    if (type === 'reset') {
      // Issue a short-lived reset token
      const resetToken = jwt.sign(
        { id: userId, purpose: 'reset' },
        process.env.JWT_SECRET,
        { expiresIn: '15m' }
      );
      return res.json({ resetToken });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/auth/resend-otp ─────────────────────────────────────────────────
router.post('/resend-otp', async (req, res) => {
  try {
    const { userId, type } = req.body;

    if (!isUuid(userId)) return res.status(404).json({ message: 'User not found' });

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    await createAndSendOtp(user.id, user.contactNumber, type);

    res.json({ message: 'OTP resent successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/auth/login ──────────────────────────────────────────────────────
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ message: 'Username and password are required' });
    }

    const user = await prisma.user.findUnique({
      where: { username },
      include: { verificationProfile: true },
    });
    if (!user) {
      return res.status(401).json({ message: 'Invalid username or password' });
    }

    const match = await comparePassword(password, user.password);
    if (!match) {
      return res.status(401).json({ message: 'Invalid username or password' });
    }

    // Account not yet verified — resend OTP
    if (!user.isVerified) {
      await createAndSendOtp(user.id, user.contactNumber, 'register');
      return res.status(403).json({
        message: 'Account not verified. OTP has been resent.',
        userId: user.id,
        requiresVerification: true,
      });
    }

    const token = generateToken(user);
    const profile = user.verificationProfile;

    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email || '',
        contactNumber: user.contactNumber,
        isVerified: user.isVerified,
        avatar: user.avatar || '',
        accountStatus: profile?.status || 'draft',
        verificationStep: profile?.currentStep || 1,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/auth/forgot-password ───────────────────────────────────────────
router.post('/forgot-password', async (req, res) => {
  try {
    const { identifier } = req.body;

    if (!identifier) {
      return res.status(400).json({ message: 'Email or contact number is required' });
    }

    const trimmed = identifier.trim();

    // Match by email or contact number
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { email: trimmed },
          { contactNumber: trimmed },
        ],
      },
    });

    if (!user) {
      // Don't reveal if user exists
      return res.json({ message: 'If that account exists, an OTP has been sent.' });
    }

    const isEmail = trimmed.includes('@');

    // Generate and save OTP
    await prisma.otpCode.deleteMany({ where: { userId: user.id, type: 'reset', used: false } });
    const code = generateOtpCode();
    const hashed = await hashPassword(code);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    await prisma.otpCode.create({
      data: { userId: user.id, code: hashed, type: 'reset', expiresAt },
    });

    if (isEmail) {
      try {
        await sendOtpEmail(user.email, code, 'reset');
        console.log(`[OTP] Reset OTP sent to email: ${user.email}`);
      } catch (emailErr) {
        console.error('[OTP] Email sending failed:', emailErr.message);
        console.log(`[OTP] Code for ${user.email}: ${code}`);
      }
    } else {
      try {
        await sendPasswordResetOtp(user.contactNumber, code);
        console.log(`[OTP] Reset OTP sent via SMS to: ${user.contactNumber}`);
      } catch (smsErr) {
        console.error('[OTP] SMS sending failed:', smsErr?.response?.data || smsErr.message);
        console.log(`[OTP] Code for ${user.contactNumber}: ${code}`);
      }
    }

    res.json({
      message: isEmail
          ? 'OTP sent to your email address'
          : 'OTP sent to your registered contact number',
      userId: user.id,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// ── POST /api/auth/reset-password ────────────────────────────────────────────
router.post('/reset-password', async (req, res) => {
  try {
    const { resetToken, newPassword, confirmPassword } = req.body;

    if (!resetToken || !newPassword || !confirmPassword) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    if (newPassword !== confirmPassword) {
      return res.status(400).json({ message: 'Passwords do not match' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    let decoded;
    try {
      decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
    } catch {
      return res.status(401).json({ message: 'Reset token is invalid or expired' });
    }

    if (decoded.purpose !== 'reset') {
      return res.status(401).json({ message: 'Invalid reset token' });
    }
    if (!isUuid(decoded.id)) return res.status(404).json({ message: 'User not found' });

    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { password: await hashPassword(newPassword) },
    });

    res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
