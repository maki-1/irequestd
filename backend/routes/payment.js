const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const authMiddleware = require('../middleware/auth');
const prisma = require('../lib/prisma');
const { isUuid } = require('../lib/ids');

const PAYMONGO_BASE = 'https://api.paymongo.com/v1';
const FALLBACK_PRICE = parseInt(process.env.DOCUMENT_PRICE_CENTAVOS || '500', 10);

const PAYMENT_METHOD_TYPES = ['gcash', 'paymaya', 'grab_pay', 'card'];

async function getPriceCentavos(documentType) {
  const entry = await prisma.documentPrice.findUnique({ where: { documentType } });
  return entry ? entry.pricecentavos : FALLBACK_PRICE;
}

async function getPurokFeeCentavos() {
  const entry = await prisma.purokClearanceFee.findUnique({ where: { purokName: 'default' } });
  return entry ? entry.feecentavos : 0;
}

// ── GET /api/payment/purok-fee ────────────────────────────────────────────────
router.get('/purok-fee', authMiddleware, async (req, res) => {
  try {
    const feeCentavos = await getPurokFeeCentavos();
    res.json({ feeCentavos, feePHP: feeCentavos / 100 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

function paymongoAuth() {
  const key = process.env.PAYMONGO_SECRET_KEY || '';
  return `Basic ${Buffer.from(`${key}:`).toString('base64')}`;
}

// ── POST /api/payment/create-session ────────────────────────────────────────
// Accepts JSON: { requestIds: [id, ...] }
// Creates a PayMongo checkout session for approved, unpaid requests.
// Adds purok clearance fee as a separate line item.
// Returns { checkoutUrl, sessionId, requestIds }
router.post('/create-session', authMiddleware, async (req, res) => {
  try {
    const { requestIds } = req.body;
    if (!Array.isArray(requestIds) || requestIds.length === 0) {
      return res.status(400).json({ message: 'At least one requestId is required' });
    }

    const requests = await prisma.request.findMany({
      where: {
        id: { in: requestIds.filter(isUuid) },
        userId: req.user.id,
        purokLeaderStatus: 'approved',
        paymentStatus: 'unpaid',
      },
    });

    if (requests.length === 0) {
      return res.status(400).json({ message: 'No approved unpaid requests found' });
    }

    const successUrl = process.env.PAYMENT_SUCCESS_URL || 'https://irequestd.onrender.com/payment/success';
    const cancelUrl = process.env.PAYMENT_CANCEL_URL || 'https://irequestd.onrender.com/payment/cancel';

    const purokFeeCentavos = await getPurokFeeCentavos();

    const docLineItems = await Promise.all(requests.map(async (r) => {
      const priceCentavos = await getPriceCentavos(r.documentType);
      return {
        currency: 'PHP',
        amount: priceCentavos,
        description: r.purpose,
        name: r.documentType,
        quantity: 1,
      };
    }));

    const lineItems = [...docLineItems];
    if (purokFeeCentavos > 0) {
      lineItems.push({
        currency: 'PHP',
        amount: purokFeeCentavos,
        description: 'Purok Clearance Fee',
        name: 'Purok Clearance',
        quantity: 1,
      });
    }

    const description = requests.length === 1
      ? `iRequestD — ${requests[0].documentType}`
      : `iRequestD — ${requests.length} Documents`;

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

    await prisma.request.updateMany({
      where: { id: { in: requests.map((r) => r.id) } },
      data: { paymentSessionId: sessionId },
    });

    res.status(201).json({
      checkoutUrl,
      sessionId,
      requestIds: requests.map((r) => r.id),
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

    const requests = await prisma.request.findMany({
      where: { paymentSessionId: sessionId, userId: req.user.id },
    });

    if (!requests.length) return res.status(404).json({ message: 'Request not found' });

    if (requests.every((r) => r.paymentStatus === 'paid')) {
      return res.json({ paid: true, requestIds: requests.map((r) => r.id) });
    }

    const pmRes = await axios.get(`${PAYMONGO_BASE}/checkout_sessions/${sessionId}`, {
      headers: { Authorization: paymongoAuth() },
    });

    const attrs = pmRes.data.data.attributes;
    const sessionStatus = attrs.status;
    const paymentIntentStatus = attrs.payment_intent?.attributes?.status;

    const isPaid = sessionStatus === 'completed' || paymentIntentStatus === 'succeeded';

    if (isPaid) {
      const purokFeeCentavos = await getPurokFeeCentavos();
      await Promise.all(requests.map(async (r) => {
        const PRICE = await getPriceCentavos(r.documentType);
        await prisma.request.update({
          where: { id: r.id },
          data: {
            paymentStatus: 'paid',
            amountPaid: (PRICE + purokFeeCentavos) / 100,
          },
        });
      }));

      return res.json({ paid: true, requestIds: requests.map((r) => r.id) });
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
        const req_ = await prisma.request.findFirst({ where: { paymentSessionId: sessionId } });
        if (req_) {
          const PRICE = await getPriceCentavos(req_.documentType);
          await prisma.request.update({
            where: { id: req_.id },
            data: { paymentStatus: 'paid', amountPaid: PRICE / 100 },
          });
        }
      }
    }

    res.json({ received: true });
  } catch (err) {
    console.error('PayMongo webhook error:', err.message);
    res.status(500).json({ message: 'Webhook handling failed' });
  }
});

// ── POST /api/payment/retry-session/:requestId ──────────────────────────────
// Creates a new checkout session for an approved, unpaid request.
// Includes purok clearance fee as a line item.
router.post('/retry-session/:requestId', authMiddleware, async (req, res) => {
  try {
    if (!isUuid(req.params.requestId)) {
      return res.status(404).json({ message: 'Unpaid request not found' });
    }

    const request = await prisma.request.findFirst({
      where: {
        id: req.params.requestId,
        userId: req.user.id,
        paymentStatus: 'unpaid',
      },
    });
    if (!request) {
      return res.status(404).json({ message: 'Unpaid request not found' });
    }
    if (request.purokLeaderStatus !== 'approved') {
      return res.status(400).json({ message: 'Request must be approved by Purok Leader before payment' });
    }

    const priceCentavos    = await getPriceCentavos(request.documentType);
    // Use the fee set at approval time (stored in PHP → convert to centavos).
    // purokClearanceFee is a Prisma Decimal, so coerce before arithmetic.
    const purokFeeCentavos = Math.round(Number(request.purokClearanceFee || 0) * 100);

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
        description: 'Purok Clearance Fee',
        name: 'Purok Clearance',
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

    await prisma.request.update({
      where: { id: request.id },
      data: { paymentSessionId: newSessionId },
    });

    res.json({
      checkoutUrl,
      sessionId: newSessionId,
      requestId: request.id,
      docPricePHP: priceCentavos / 100,
      purokFeePHP: purokFeeCentavos / 100,
      totalPHP: (priceCentavos + purokFeeCentavos) / 100,
    });
  } catch (err) {
    console.error('PayMongo retry-session error:', err?.response?.data || err.message);
    res.status(500).json({ message: 'Failed to create retry checkout session' });
  }
});

// ── POST /api/payment/dev-skip/:requestId ────────────────────────────────────
if (process.env.NODE_ENV !== 'production') {
  router.post('/dev-skip/:requestId', authMiddleware, async (req, res) => {
    if (!isUuid(req.params.requestId)) {
      return res.status(404).json({ message: 'Request not found' });
    }
    const { count } = await prisma.request.updateMany({
      where: { id: req.params.requestId, userId: req.user.id },
      data: { paymentStatus: 'paid', amountPaid: FALLBACK_PRICE / 100 },
    });
    if (count === 0) return res.status(404).json({ message: 'Request not found' });
    res.json({ paid: true, requestId: req.params.requestId });
  });
}

module.exports = router;
