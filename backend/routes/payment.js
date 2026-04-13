const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const authMiddleware = require('../middleware/auth');
const Request = require('../models/Request');

const PAYMONGO_BASE = 'https://api.paymongo.com/v1';
const PRICE = parseInt(process.env.DOCUMENT_PRICE_CENTAVOS || '500', 10); // ₱5.00

function paymongoAuth() {
  const key = process.env.PAYMONGO_SECRET_KEY || '';
  return `Basic ${Buffer.from(`${key}:`).toString('base64')}`;
}

// ── POST /api/payment/create-link ────────────────────────────────────────────
// Creates a PayMongo payment link + a pending request record.
// Returns { checkoutUrl, linkId, requestId }
router.post('/create-link', authMiddleware, async (req, res) => {
  try {
    const { documentType, purpose, additionalDetails, deliveryMethod } = req.body;

    if (!documentType || !purpose || !deliveryMethod) {
      return res.status(400).json({ message: 'Document type, purpose, and delivery method are required' });
    }

    // 1. Create PayMongo payment link
    const pmRes = await axios.post(
      `${PAYMONGO_BASE}/links`,
      {
        data: {
          attributes: {
            amount: PRICE,
            description: `iRequestD — ${documentType}`,
            remarks: `${purpose}${additionalDetails ? ` | ${additionalDetails}` : ''}`,
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

    const linkData = pmRes.data.data;
    const linkId = linkData.id;
    const checkoutUrl = linkData.attributes.checkout_url;

    // 2. Create request record (paymentStatus: unpaid until webhook fires)
    const request = await Request.create({
      user: req.user.id,
      documentType,
      purpose,
      additionalDetails: additionalDetails || '',
      deliveryMethod,
      paymentStatus: 'unpaid',
      paymentLinkId: linkId,
      amountPaid: 0,
    });

    res.status(201).json({
      checkoutUrl,
      linkId,
      requestId: request._id,
    });
  } catch (err) {
    console.error('PayMongo create-link error:', err?.response?.data || err.message);
    res.status(500).json({ message: 'Failed to create payment link' });
  }
});

// ── GET /api/payment/status/:linkId ─────────────────────────────────────────
// Polls the PayMongo link status and syncs local request record.
router.get('/status/:linkId', authMiddleware, async (req, res) => {
  try {
    const { linkId } = req.params;

    // Check our DB first
    const request = await Request.findOne({
      paymentLinkId: linkId,
      user: req.user.id,
    });

    if (!request) return res.status(404).json({ message: 'Request not found' });

    if (request.paymentStatus === 'paid') {
      return res.json({ paid: true, requestId: request._id });
    }

    // Double-check directly with PayMongo
    const pmRes = await axios.get(`${PAYMONGO_BASE}/links/${linkId}`, {
      headers: { Authorization: paymongoAuth() },
    });

    const linkStatus = pmRes.data.data.attributes.status;

    if (linkStatus === 'paid') {
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
// PayMongo calls this when a link is paid.
// Verify the signature, then mark the matching request as paid.
router.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  try {
    const webhookSecret = process.env.PAYMONGO_WEBHOOK_SECRET || '';

    // Signature verification (skip if secret not set — dev mode)
    if (webhookSecret) {
      const sigHeader = req.headers['paymongo-signature'];
      if (!sigHeader) return res.status(400).json({ message: 'Missing signature' });

      // PayMongo signature format: t=<timestamp>,te=<test_sig>,li=<live_sig>
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

    if (eventType === 'link.payment.paid') {
      const linkId = body?.data?.attributes?.data?.attributes?.link_id;
      if (linkId) {
        await Request.findOneAndUpdate(
          { paymentLinkId: linkId },
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

module.exports = router;
