const nodemailer = require('nodemailer');

function createTransporter() {
  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true, // SSL
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });
}

async function sendOtpEmail(to, otp, type = 'reset') {
  const transporter = createTransporter();

  const subject =
    type === 'reset'
      ? 'iRequest Dologon — Password Reset OTP'
      : 'iRequest Dologon — Verification Code';

  const body =
    type === 'reset'
      ? `Your password reset code is: <b>${otp}</b><br>Valid for 10 minutes. Ignore if you did not request this.`
      : `Your verification code is: <b>${otp}</b><br>Valid for 10 minutes. Do not share this code.`;

  const info = await transporter.sendMail({
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

  console.log(`[Email] Message sent: ${info.messageId}`);
  return info;
}

// ── Purok Clearance Form ──────────────────────────────────────────────────────
// data: { fullName, purokNumber, controlNo, date }
async function sendPurokClearanceForm(to, { fullName, purokNumber, controlNo, date, treasurerName = '', purokPresident = '' }) {
  const transporter = createTransporter();

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { margin: 0; padding: 0; background: #f5f5f5; font-family: 'Times New Roman', Times, serif; }
    .wrapper { max-width: 560px; margin: 32px auto; background: #fff; padding: 0; }
    .form-box {
      border: 2px solid #000;
      padding: 28px 32px;
      margin: 0;
    }
    .header { text-align: center; margin-bottom: 4px; }
    .header p { margin: 2px 0; font-size: 14px; }
    .header-bold { font-weight: bold; }
    .meta-row {
      display: flex;
      justify-content: flex-end;
      font-size: 13px;
      margin: 4px 0;
    }
    .title-row {
      text-align: center;
      margin: 6px 0 2px 0;
    }
    .title {
      font-size: 20px;
      font-weight: bold;
      letter-spacing: 1px;
      text-decoration: underline;
    }
    .date-row {
      text-align: right;
      font-size: 13px;
      margin-bottom: 16px;
    }
    .salutation { font-weight: bold; font-size: 14px; margin: 14px 0 10px 0; }
    .body-text {
      font-size: 14px;
      text-align: justify;
      line-height: 1.7;
      margin-bottom: 14px;
    }
    .indent { display: inline-block; width: 36px; }
    .underline { text-decoration: underline; font-weight: bold; }
    .sig-row {
      display: flex;
      justify-content: space-between;
      margin-top: 36px;
      font-size: 13px;
    }
    .sig-block { text-align: center; }
    .sig-line { border-top: 1px solid #000; width: 160px; margin: 0 auto 4px auto; }
    .noted-label { font-style: italic; margin-bottom: 6px; }
    .footer-note {
      text-align: center;
      font-size: 11px;
      color: #888;
      margin-top: 20px;
      padding: 0 32px 16px;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="form-box">

      <div class="header">
        <p>Republic of the Philippines</p>
        <p>Municipality of Maramag</p>
        <p class="header-bold">Barangay Dologon</p>
      </div>

      <div class="meta-row">Control No. &nbsp;<strong>${controlNo}</strong></div>

      <div class="title-row">
        <span class="title">PUROK CLEARANCE</span>
      </div>

      <div class="date-row">Date: &nbsp;<strong>${date}</strong></div>

      <div class="salutation">TO WHOM IT MAY CONCERN:</div>

      <p class="body-text">
        <span class="indent"></span>This is to certify that
        <span class="underline">${fullName}</span>
        of Purok <strong>${purokNumber}</strong> Dologon,
        Maramag, Bukidnon has no money/property accountability
        to the Purok.
      </p>

      <p class="body-text">
        <span class="indent"></span>This certification is issued upon the request of the
        above-named person for whatever purpose that may serve him/her best.
      </p>

      <div class="sig-row">
        <div class="sig-block">
          <div class="sig-line"></div>
          ${treasurerName
            ? `<div style="font-weight:bold;">${treasurerName}</div>`
            : ''}
          <div>Purok Treasurer</div>
        </div>
        <div class="sig-block">
          <div class="noted-label">Noted by:</div>
          <div class="sig-line"></div>
          ${purokPresident
            ? `<div style="font-weight:bold;">${purokPresident}</div>`
            : ''}
          <div>Purok President</div>
        </div>
      </div>

    </div>
    <div class="footer-note">
      This is an official document from Barangay Dologon, Municipality of Maramag, Bukidnon.<br>
      Sent via iRequestD — please keep this for your records.
    </div>
  </div>
</body>
</html>
  `;

  const info = await transporter.sendMail({
    from: `"iRequest Dologon" <${process.env.EMAIL_USER}>`,
    to,
    subject: 'iRequest Dologon — Your Purok Clearance Form',
    html,
  });

  console.log(`[Email] Purok Clearance form sent to ${to}: ${info.messageId}`);
  return info;
}

module.exports = { sendOtpEmail, sendPurokClearanceForm };
