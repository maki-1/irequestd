const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const authMiddleware = require('../middleware/auth');
const Request = require('../models/Request');
const VerificationProfile = require('../models/VerificationProfile');

const DocumentPrice = require('../models/DocumentPrice');

const PAYMONGO_BASE = 'https://api.paymongo.com/v1';
const FALLBACK_PRICE = parseInt(process.env.DOCUMENT_PRICE_CENTAVOS || '500', 10);

const PAYMENT_METHOD_TYPES = ['gcash', 'paymaya', 'grab_pay', 'card'];

async function getPriceCentavos(documentType) {
  const entry = await DocumentPrice.findOne({ documentType });
  return entry ? entry.pricecentavos : FALLBACK_PRICE;
}

function paymongoAuth() {
  const key = process.env.PAYMONGO_SECRET_KEY || '';
  return `Basic ${Buffer.from(`${key}:`).toString('base64')}`;
}

// ── POST /api/payment/create-session ────────────────────────────────────────
// Creates a PayMongo checkout session + a pending request record.
// Returns { checkoutUrl, sessionId, requestId }
router.post('/create-session', authMiddleware, async (req, res) => {
  try {
    const { documentType, purpose, additionalDetails, deliveryMethod } = req.body;

    if (!documentType || !purpose || !deliveryMethod) {
      return res.status(400).json({ message: 'Document type, purpose, and delivery method are required' });
    }

    const profile = await VerificationProfile.findOne({ user: req.user.id });
    const yearsAtAddress = profile?.yearsAtAddress || '';

    const PRICE = await getPriceCentavos(documentType);
    const successUrl = process.env.PAYMENT_SUCCESS_URL || 'https://irequestd.onrender.com';
    const cancelUrl = process.env.PAYMENT_CANCEL_URL || 'https://irequestd.onrender.com';

    const pmRes = await axios.post(
      `${PAYMONGO_BASE}/checkout_sessions`,
      {
        data: {
          attributes: {
            send_email_receipt: true,
            show_description: true,
            show_line_items: true,
            line_items: [
              {
                currency: 'PHP',
                amount: PRICE,
                description: `${purpose}${additionalDetails ? ` — ${additionalDetails}` : ''}`,
                name: documentType,
                quantity: 1,
              },
            ],
            payment_method_types: PAYMENT_METHOD_TYPES,
            success_url: successUrl,
            cancel_url: cancelUrl,
            description: `iRequestD — ${documentType}`,
          },
        },
      },
      {
        headers: {
          Authorization: paymongoAuth(),
          'Content-Type': 'application/json',
        },
      }
    );

    const sessionData = pmRes.data.data;
    const sessionId = sessionData.id;
    const checkoutUrl = sessionData.attributes.checkout_url;

    const request = await Request.create({
      user: req.user.id,
      documentType,
      purpose,
      additionalDetails: additionalDetails || '',
      deliveryMethod,
      paymentStatus: 'unpaid',
      paymentSessionId: sessionId,
      amountPaid: 0,
    });

    res.status(201).json({ checkoutUrl, sessionId, requestId: request._id });
  } catch (err) {
    console.error('PayMongo create-session error:', err?.response?.data || err.message);
    res.status(500).json({ message: 'Failed to create checkout session' });
  }
});

// ── GET /api/payment/status/:sessionId ──────────────────────────────────────
// Polls the PayMongo checkout session status and syncs local request record.
router.get('/status/:sessionId', authMiddleware, async (req, res) => {
  try {
    const { sessionId } = req.params;

    const request = await Request.findOne({
      paymentSessionId: sessionId,
      user: req.user.id,
    });

    if (!request) return res.status(404).json({ message: 'Request not found' });

    if (request.paymentStatus === 'paid') {
      return res.json({ paid: true, requestId: request._id });
    }

    const pmRes = await axios.get(`${PAYMONGO_BASE}/checkout_sessions/${sessionId}`, {
      headers: { Authorization: paymongoAuth() },
    });

    const attrs = pmRes.data.data.attributes;
    const sessionStatus = attrs.status;
    const paymentIntentStatus = attrs.payment_intent?.attributes?.status;

    const isPaid = sessionStatus === 'completed' || paymentIntentStatus === 'succeeded';

    if (isPaid) {
      const PRICE = await getPriceCentavos(request.documentType);
      request.paymentStatus = 'paid';
      request.amountPaid = PRICE;
      await request.save();
      return res.json({ paid: true, requestId: request._id });
    }

    res.json({ paid: false, requestId: request._id });
  } catch (err) {
    console.error('PayMongo status error:', err?.response?.data || err.message);
    res.status(500).json({ message: 'Failed to check payment status' });
  }
});

// ── POST /api/payment/webhook ────────────────────────────────────────────────
// PayMongo calls this when a checkout session is paid.
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  try {
    const webhookSecret = process.env.PAYMONGO_WEBHOOK_SECRET || '';

    if (webhookSecret) {
      const sigHeader = req.headers['paymongo-signature'];
      if (!sigHeader) return res.status(400).json({ message: 'Missing signature' });

      const parts = Object.fromEntries(
        sigHeader.split(',').map((p) => p.split('='))
      );
      const timestamp = parts.t;
      const signature = parts.te || parts.li;
      const payload = `${timestamp}.${req.body.toString()}`;
      const expected = crypto
        .createHmac('sha256', webhookSecret)
        .update(payload)
        .digest('hex');

      if (signature !== expected) {
        return res.status(400).json({ message: 'Invalid signature' });
      }
    }

    const body = JSON.parse(req.body.toString());
    const eventType = body?.data?.attributes?.type;

    if (eventType === 'checkout_session.payment.paid') {
      const sessionId = body?.data?.attributes?.data?.id;
      if (sessionId) {
        const req_ = await Request.findOne({ paymentSessionId: sessionId });
        const PRICE = req_ ? await getPriceCentavos(req_.documentType) : FALLBACK_PRICE;
        await Request.findOneAndUpdate(
          { paymentSessionId: sessionId },
          { paymentStatus: 'paid', amountPaid: PRICE }
        );
      }
    }

    res.json({ received: true });
  } catch (err) {
    console.error('PayMongo webhook error:', err.message);
    res.status(500).json({ message: 'Webhook handling failed' });
  }
});

// ── POST /api/payment/dev-skip/:requestId ────────────────────────────────────
if (process.env.NODE_ENV !== 'production') {
  router.post('/dev-skip/:requestId', authMiddleware, async (req, res) => {
    const request = await Request.findOneAndUpdate(
      { _id: req.params.requestId, user: req.user.id },
      { paymentStatus: 'paid', amountPaid: FALLBACK_PRICE },
      { new: true }
    );
    if (!request) return res.status(404).json({ message: 'Request not found' });
    res.json({ paid: true, requestId: request._id });
  });
}

module.exports = router;
