const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const authMiddleware = require('../middleware/auth');
const Request = require('../models/Request');
const User = require('../models/User');
const VerificationProfile = require('../models/VerificationProfile');
const DocumentPrice = require('../models/DocumentPrice');
const { uploadRequestPhoto } = require('../config/cloudinary');

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
// Accepts multipart: items (JSON string), requestPhoto file, per-item controlNumber inside items.
// Creates one PayMongo checkout session with multiple line items + one Request per doc.
// Returns { checkoutUrl, sessionId, requestIds }
// Each document requires its own purok clearance photo (field: purokClearances[])
router.post('/create-session', authMiddleware, uploadRequestPhoto.array('purokClearances', 10), async (req, res) => {
  try {
    let items;
    try {
      items = typeof req.body.items === 'string' ? JSON.parse(req.body.items) : req.body.items;
    } catch {
      return res.status(400).json({ message: 'Invalid items format' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'At least one document item is required' });
    }
    const files = req.files || [];
    if (files.length !== items.length) {
      return res.status(400).json({ message: 'A purok clearance photo is required for each document' });
    }
    for (const item of items) {
      if (!item.documentType || !item.purpose || !item.deliveryMethod) {
        return res.status(400).json({ message: 'Each item requires documentType, purpose, and deliveryMethod' });
      }
    }

    const successUrl = process.env.PAYMENT_SUCCESS_URL || 'https://irequestd.onrender.com/payment/success';
    const cancelUrl = process.env.PAYMENT_CANCEL_URL || 'https://irequestd.onrender.com/payment/cancel';

    // Resolve prices for all items
    const itemsWithPrice = await Promise.all(items.map(async (item) => {
      const basePriceCentavos = await getPriceCentavos(item.documentType);
      return { ...item, basePriceCentavos };
    }));

    const lineItems = itemsWithPrice.map((item) => ({
      currency: 'PHP',
      amount: item.basePriceCentavos,
      description: `${item.purpose}${item.additionalDetails ? ` — ${item.additionalDetails}` : ''}`,
      name: item.documentType,
      quantity: 1,
    }));

    const description = items.length === 1
      ? `iRequestD — ${items[0].documentType}`
      : `iRequestD — ${items.length} Documents`;

    const pmRes = await axios.post(
      `${PAYMONGO_BASE}/checkout_sessions`,
      {
        data: {
          attributes: {
            send_email_receipt: true,
            show_description: true,
            show_line_items: true,
            line_items: lineItems,
            payment_method_types: PAYMENT_METHOD_TYPES,
            success_url: successUrl,
            cancel_url: cancelUrl,
            description,
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

    // Create one Request record per document, each with its own purok clearance photo
    const requests = await Promise.all(itemsWithPrice.map((item, i) =>
      Request.create({
        user: req.user.id,
        documentType: item.documentType,
        purpose: item.purpose,
        additionalDetails: item.additionalDetails || '',
        deliveryMethod: item.deliveryMethod,
        controlNumber: (item.controlNumber || '').trim(),
        requestPhoto: files[i].path,
        paymentStatus: 'unpaid',
        paymentSessionId: sessionId,
        amountPaid: 0,
      })
    ));

    res.status(201).json({
      checkoutUrl,
      sessionId,
      requestIds: requests.map((r) => r._id),
      requestId: requests[0]._id, // backward compat
    });
  } catch (err) {
    console.error('PayMongo create-session error:', err?.response?.data || err.message);
    res.status(500).json({ message: 'Failed to create checkout session' });
  }
});

// ── GET /api/payment/status/:sessionId ──────────────────────────────────────
// Polls PayMongo and marks ALL requests for the session as paid.
router.get('/status/:sessionId', authMiddleware, async (req, res) => {
  try {
    const { sessionId } = req.params;

    const requests = await Request.find({
      paymentSessionId: sessionId,
      user: req.user.id,
    });

    if (!requests.length) return res.status(404).json({ message: 'Request not found' });

    if (requests.every((r) => r.paymentStatus === 'paid')) {
      return res.json({ paid: true, requestIds: requests.map((r) => r._id) });
    }

    const pmRes = await axios.get(`${PAYMONGO_BASE}/checkout_sessions/${sessionId}`, {
      headers: { Authorization: paymongoAuth() },
    });

    const attrs = pmRes.data.data.attributes;
    const sessionStatus = attrs.status;
    const paymentIntentStatus = attrs.payment_intent?.attributes?.status;

    const isPaid = sessionStatus === 'completed' || paymentIntentStatus === 'succeeded';

    if (isPaid) {
      await Promise.all(requests.map(async (r) => {
        const PRICE = await getPriceCentavos(r.documentType);
        r.paymentStatus = 'paid';
        r.amountPaid = PRICE / 100;
        await r.save();
      }));

      return res.json({ paid: true, requestIds: requests.map((r) => r._id) });
    }

    res.json({ paid: false });
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
          { paymentStatus: 'paid', amountPaid: PRICE / 100 }
        );
      }
    }

    res.json({ received: true });
  } catch (err) {
    console.error('PayMongo webhook error:', err.message);
    res.status(500).json({ message: 'Webhook handling failed' });
  }
});

// ── POST /api/payment/retry-session/:requestId ──────────────────────────────
// Creates a new checkout session for an existing unpaid request.
router.post('/retry-session/:requestId', authMiddleware, async (req, res) => {
  try {
    const request = await Request.findOne({
      _id: req.params.requestId,
      user: req.user.id,
      paymentStatus: 'unpaid',
    });
    if (!request) {
      return res.status(404).json({ message: 'Unpaid request not found' });
    }

    const priceCentavos = await getPriceCentavos(request.documentType);

    const lineItems = [
      {
        currency: 'PHP',
        amount: priceCentavos,
        description: request.purpose,
        name: request.documentType,
        quantity: 1,
      },
    ];

    const successUrl = process.env.PAYMENT_SUCCESS_URL || 'https://irequestd.onrender.com/payment/success';
    const cancelUrl  = process.env.PAYMENT_CANCEL_URL  || 'https://irequestd.onrender.com/payment/cancel';

    const pmRes = await axios.post(
      `${PAYMONGO_BASE}/checkout_sessions`,
      {
        data: {
          attributes: {
            send_email_receipt: true,
            show_description: true,
            show_line_items: true,
            line_items: lineItems,
            payment_method_types: PAYMENT_METHOD_TYPES,
            success_url: successUrl,
            cancel_url: cancelUrl,
            description: `iRequestD — ${request.documentType}`,
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

    const sessionData  = pmRes.data.data;
    const newSessionId = sessionData.id;
    const checkoutUrl  = sessionData.attributes.checkout_url;

    request.paymentSessionId = newSessionId;
    await request.save();

    res.json({ checkoutUrl, sessionId: newSessionId, requestId: request._id });
  } catch (err) {
    console.error('PayMongo retry-session error:', err?.response?.data || err.message);
    res.status(500).json({ message: 'Failed to create retry checkout session' });
  }
});

// ── POST /api/payment/dev-skip/:requestId ────────────────────────────────────
if (process.env.NODE_ENV !== 'production') {
  router.post('/dev-skip/:requestId', authMiddleware, async (req, res) => {
    const request = await Request.findOneAndUpdate(
      { _id: req.params.requestId, user: req.user.id },
      { paymentStatus: 'paid', amountPaid: FALLBACK_PRICE / 100 },
      { new: true }
    );
    if (!request) return res.status(404).json({ message: 'Request not found' });
    res.json({ paid: true, requestId: request._id });
  });
}

module.exports = router;
