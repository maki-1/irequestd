const nodemailer = require('nodemailer');

function createTransporter(env = process.env) {
  const user = String(env.EMAIL_USER || '').trim();
  const pass = String(env.EMAIL_PASS || '').trim();
  if (!user || !pass) {
    throw Object.assign(new Error('Email is not configured: set EMAIL_USER and EMAIL_PASS on this backend.'), { code: 'EMAIL_CONFIG' });
  }
  return nodemailer.createTransport({
    host: 'smtp.gmail.com', port: 465, secure: true,
    auth: { user, pass: pass.replace(/\s/g, '') },
    connectionTimeout: 10000, greetingTimeout: 10000, socketTimeout: 10000,
  });
}

function deliveryError(error) {
  if (error.code === 'EAUTH') {
    return Object.assign(new Error('Email authentication failed. Check EMAIL_USER and the Gmail app password in EMAIL_PASS on this backend.'), { code: 'EAUTH', responseCode: error.responseCode });
  }
  return error;
}

async function sendEmail({ to, subject, html, text }) {
  const transporter = createTransporter();
  try {
    const result = await transporter.sendMail({
      from: { name: 'iRequestDologon', address: process.env.EMAIL_USER.trim() },
      to, subject, html, ...(text ? { text } : {}),
    });
    if (!result.accepted?.length || result.rejected?.length) {
      throw Object.assign(new Error('The email provider did not accept the recipient.'), { code: 'EMAIL_REJECTED' });
    }
    // SMTP acceptance is not proof that the message reached the inbox.
    return result;
  } catch (error) { throw deliveryError(error); }
  finally { transporter.close?.(); }
}

async function verifyEmailConnection() {
  const transporter = createTransporter();
  try { return await transporter.verify(); }
  catch (error) { throw deliveryError(error); }
  finally { transporter.close?.(); }
}

module.exports = { createTransporter, sendEmail, verifyEmailConnection };
