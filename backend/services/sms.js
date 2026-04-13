const axios = require('axios');

// Convert Philippine number to E.164 format (+639XXXXXXXXX)
function toE164(phone) {
  const digits = phone.replace(/\D/g, '');
  if (digits.startsWith('63')) return `+${digits}`;
  if (digits.startsWith('0')) return `+63${digits.slice(1)}`;
  return `+63${digits}`;
}

async function sendSms(to, message) {
  const credentials = Buffer.from(`${process.env.UNISMS_API_KEY}:`).toString('base64');

  const response = await axios.post(
    'https://unismsapi.com/api/sms',
    {
      recipient: toE164(to),
      content: message,
      ...(process.env.UNISMS_SENDER_ID ? { sender_id: process.env.UNISMS_SENDER_ID } : {}),
    },
    {
      headers: {
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/json',
      },
    }
  );

  return response.data;
}

async function sendOtp(to, otp) {
  return sendSms(
    to,
    `Your iRequest Dologon verification code is: ${otp}. Valid for 10 minutes. Do not share this code.`
  );
}

async function sendPasswordResetOtp(to, otp) {
  return sendSms(
    to,
    `Your iRequest Dologon password reset code is: ${otp}. Valid for 10 minutes. Ignore if you did not request this.`
  );
}

module.exports = { sendOtp, sendPasswordResetOtp };
