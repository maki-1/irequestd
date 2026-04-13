const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Otp = require('../models/Otp');
const VerificationProfile = require('../models/VerificationProfile');
const { sendOtp, sendPasswordResetOtp } = require('../services/sms');
const { uploadAvatar } = require('../config/cloudinary');

function generateToken(user) {
  return jwt.sign(
    { id: user._id, username: user.username },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN }
  );
}

function generateOtpCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function createAndSendOtp(userId, contactNumber, type) {
  // Invalidate any existing unused OTPs of same type
  await Otp.deleteMany({ userId, type, used: false });

  const code = generateOtpCode();
  const hashed = await bcrypt.hash(code, 10);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

  await Otp.create({ userId, code: hashed, type, expiresAt });

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
    const user = await User.findById(req.user.id).select('-password');
    if (!user) return res.status(404).json({ message: 'User not found' });

    const profile = await VerificationProfile.findOne({ user: user._id });

    res.json({
      id: user._id,
      username: user.username,
      email: user.email,
      contactNumber: user.contactNumber,
      isVerified: user.isVerified,
      avatar: user.avatar || '',
      accountStatus: profile?.status || 'draft',
      verificationStep: profile?.currentStep || 1,
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

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    // Cloudinary returns the full secure URL in req.file.path
    user.avatar = req.file.path;
    await user.save();

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

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const match = await user.comparePassword(currentPassword);
    if (!match) return res.status(401).json({ message: 'Current password is incorrect' });

    user.password = newPassword;
    await user.save();

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

    const exists = await User.findOne({ username: username.trim() });
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
    const exists = await User.findOne({ contactNumber: digits });
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

    const exists = await User.findOne({ email: email.trim().toLowerCase() });
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

    // Check for duplicates before creating
    const [existingUsername, existingContact, existingEmail] = await Promise.all([
      User.findOne({ username }),
      User.findOne({ contactNumber: contactNumber.replace(/\D/g, '') }),
      email ? User.findOne({ email: email.toLowerCase() }) : Promise.resolve(null),
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

    const user = await User.create({
      username,
      contactNumber: contactNumber.replace(/\D/g, ''),
      email: email ? email.toLowerCase() : '',
      password,
      isVerified: false,
    });

    await createAndSendOtp(user._id, user.contactNumber, 'register');

    res.status(201).json({
      message: 'OTP sent to your contact number',
      userId: user._id,
      requiresVerification: true,
    });
  } catch (err) {
    // Catch MongoDB duplicate key errors as a safety net
    if (err.code === 11000) {
      const field = Object.keys(err.keyPattern || {})[0];
      const messages = {
        username: 'Username already taken',
        contactNumber: 'Contact number already registered',
        email: 'Email already registered',
      };
      return res.status(409).json({ message: messages[field] || 'Duplicate entry' });
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

    const otpRecord = await Otp.findOne({
      userId,
      type,
      used: false,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    if (!otpRecord) {
      return res.status(400).json({ message: 'OTP expired or not found. Please request a new one.' });
    }

    const match = await bcrypt.compare(code, otpRecord.code);
    if (!match) {
      return res.status(400).json({ message: 'Invalid OTP. Please try again.' });
    }

    // Mark OTP as used
    otpRecord.used = true;
    await otpRecord.save();

    if (type === 'register') {
      const user = await User.findByIdAndUpdate(userId, { isVerified: true }, { new: true });
      const token = generateToken(user);
      return res.json({
        token,
        user: {
          id: user._id,
          username: user.username,
          email: user.email,
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

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    await createAndSendOtp(user._id, user.contactNumber, type);

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

    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({ message: 'Invalid username or password' });
    }

    const match = await user.comparePassword(password);
    if (!match) {
      return res.status(401).json({ message: 'Invalid username or password' });
    }

    // Account not yet verified — resend OTP
    if (!user.isVerified) {
      await createAndSendOtp(user._id, user.contactNumber, 'register');
      return res.status(403).json({
        message: 'Account not verified. OTP has been resent.',
        userId: user._id,
        requiresVerification: true,
      });
    }

    const token = generateToken(user);

    const profile = await VerificationProfile.findOne({ user: user._id });

    res.json({
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
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
    const { username } = req.body;

    if (!username) {
      return res.status(400).json({ message: 'Username is required' });
    }

    const user = await User.findOne({ username });
    if (!user) {
      // Don't reveal if user exists
      return res.json({ message: 'If that username exists, an OTP has been sent.' });
    }

    await createAndSendOtp(user._id, user.contactNumber, 'reset');

    res.json({
      message: 'OTP sent to your registered contact number',
      userId: user._id,
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

    const user = await User.findById(decoded.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.password = newPassword;
    await user.save(); // pre-save hook hashes the password

    res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
