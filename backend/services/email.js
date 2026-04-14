const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS, // Gmail App Password
  },
});

async function sendOtpEmail(to, otp, type = 'reset') {
  const subject =
    type === 'reset'
      ? 'iRequest Dologon — Password Reset OTP'
      : 'iRequest Dologon — Verification Code';

  const body =
    type === 'reset'
      ? `Your password reset code is: <b>${otp}</b><br>Valid for 10 minutes. Ignore if you did not request this.`
      : `Your verification code is: <b>${otp}</b><br>Valid for 10 minutes. Do not share this code.`;

  await transporter.sendMail({
    from: `"iRequest Dologon" <${process.env.EMAIL_USER}>`,
    to,
    subject,
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px;border-radius:12px;border:1px solid #e0e0e0;">
        <h2 style="color:#1A6B1A;">iRequest Dologon</h2>
        <p style="font-size:15px;color:#333;">${body}</p>
        <div style="margin:24px 0;text-align:center;">
          <span style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#1A6B1A;">${otp}</span>
        </div>
        <p style="font-size:12px;color:#999;">This code expires in 10 minutes.</p>
      </div>
    `,
  });
}

module.exports = { sendOtpEmail };
