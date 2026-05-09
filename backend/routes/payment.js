const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const authMiddleware = require('../middleware/auth');
const Request = require('../models/Request');
const User = require('../models/User');
const VerificationProfile = require('../models/VerificationProfile');
const DocumentPrice = require('../models/DocumentPrice');
const PurokClearanceFee = require('../models/PurokClearanceFee');
const { sendPurokClearanceForm } = require('../services/email');

const PAYMONGO_BASE = 'https://api.paymongo.com/v1';
const FALLBACK_PRICE = parseInt(process.env.DOCUMENT_PRICE_CENTAVOS || '500', 10);

const PAYMENT_METHOD_TYPES = ['gcash', 'paymaya', 'grab_pay', 'card'];

async function getPriceCentavos(documentType) {
  const entry = await DocumentPrice.findOne({ documentType });
  return entry ? entry.pricecentavos : FALLBACK_PRICE;
}

async function getPurokFeeCentavos(userId) {
  const profile = await VerificationProfile.findOne({ user: userId });
  if (!profile?.address) return 0;
  const match = profile.address.match(/^(Purok\s+\d+)/i);
  if (!match) return 0;
  const fee = await PurokClearanceFee.findOne({ purokName: match[1] });
  return fee ? fee.feecentavos : 0;
}

function paymongoAuth() {
  const key = process.env.PAYMONGO_SECRET_KEY || '';
  return `Basic ${Buffer.from(`${key}:`).toString('base64')}`;
}

// ── POST /api/payment/create-session ────────────────────────────────────────
// Accepts items: [{ documentType, purpose, additionalDetails, deliveryMethod }]
// Creates one PayMongo checkout session with multiple line items + one Request per doc.
// Returns { checkoutUrl, sessionId, requestIds }
router.post('/create-session', authMiddleware, async (req, res) => {
  try {
    const items = req.body.items;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ message: 'At least one document item is required' });
    }
    for (const item of items) {
      if (!item.documentType || !item.purpose || !item.deliveryMethod) {
        return res.status(400).json({ message: 'Each item requires documentType, purpose, and deliveryMethod' });
      }
    }

    const successUrl = process.env.PAYMENT_SUCCESS_URL || 'https://irequestd.onrender.com/payment/success';
    const cancelUrl = process.env.PAYMENT_CANCEL_URL || 'https://irequestd.onrender.com/payment/cancel';

    // Resolve purok clearance fee once if any Barangay Clearance in the order
    const hasClearance = items.some((item) => item.documentType === 'Barangay Clearance');
    const purokFeeCentavos = hasClearance ? await getPurokFeeCentavos(req.user.id) : 0;

    // Resolve prices for all items
    const itemsWithPrice = await Promise.all(items.map(async (item) => {
      const basePriceCentavos = await getPriceCentavos(item.documentType);
      const itemPurokFee = item.documentType === 'Barangay Clearance' ? purokFeeCentavos : 0;
      return { ...item, basePriceCentavos, purokFeeCentavos: itemPurokFee };
    }));

    const lineItems = [];
    for (const item of itemsWithPrice) {
      lineItems.push({
        currency: 'PHP',
        amount: item.basePriceCentavos,
        description: `${item.purpose}${item.additionalDetails ? ` — ${item.additionalDetails}` : ''}`,
        name: item.documentType,
        quantity: 1,
      });
      if (item.purokFeeCentavos > 0) {
        lineItems.push({
          currency: 'PHP',
          amount: item.purokFeeCentavos,
          description: 'Additional purok clearance fee',
          name: 'Purok Clearance Fee',
          quantity: 1,
        });
      }
    }

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

    // Create one Request record per document
    const requests = await Promise.all(itemsWithPrice.map((item) =>
      Request.create({
        user: req.user.id,
        documentType: item.documentType,
        purpose: item.purpose,
        additionalDetails: item.additionalDetails || '',
        deliveryMethod: item.deliveryMethod,
        paymentStatus: 'unpaid',
        paymentSessionId: sessionId,
        amountPaid: 0,
        purokClearanceFee: item.purokFeeCentavos / 100,
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
        r.amountPaid = PRICE / 100 + (r.purokClearanceFee || 0);
        await r.save();
      }));

      // Send Purok Clearance form for every Barangay Clearance that includes a purok fee
      const purokRequests = requests.filter(
        (r) => r.documentType === 'Barangay Clearance' && (r.purokClearanceFee || 0) > 0
      );
      if (purokRequests.length > 0) {
        try {
          const [user, profile] = await Promise.all([
            User.findById(req.user.id).select('email'),
            VerificationProfile.findOne({ user: req.user.id }).select('fullName address'),
          ]);
          if (user?.email && profile) {
            const purokMatch = (profile.address || '').match(/^(Purok\s+(\d+))/i);
            const purokName   = purokMatch ? purokMatch[1] : null;
            const purokNumber = purokMatch ? purokMatch[2] : '—';
            const purokFeeDoc = purokName
              ? await PurokClearanceFee.findOne({ purokName }).select('treasurerName purokPresident')
              : null;
            const date = new Date().toLocaleDateString('en-PH', {
              year: 'numeric', month: 'long', day: 'numeric',
            });
            for (const r of purokRequests) {
              await sendPurokClearanceForm(user.email, {
                fullName: profile.fullName || '—',
                purokNumber,
                controlNo: r.orNumber || r._id.toString().slice(-6).toUpperCase(),
                date,
                treasurerName:  purokFeeDoc?.treasurerName  || '',
                purokPresident: purokFeeDoc?.purokPresident || '',
              });
            }
          }
        } catch (emailErr) {
          console.error('[Email] Failed to send Purok Clearance form:', emailErr.message);
        }
      }

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
    const purokFeeCentavos = Math.round((request.purokClearanceFee || 0) * 100);

    const lineItems = [
      {
        currency: 'PHP',
        amount: priceCentavos,
        description: request.purpose,
        name: request.documentType,
        quantity: 1,
      },
    ];
    if (purokFeeCentavos > 0) {
      lineItems.push({
        currency: 'PHP',
        amount: purokFeeCentavos,
        description: 'Additional purok clearance fee',
        name: 'Purok Clearance Fee',
        quantity: 1,
      });
    }

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
