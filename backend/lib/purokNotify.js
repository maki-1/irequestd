const prisma = require('./prisma');
const { buildLink, portalUrl } = require('./approveLink');
const { notificationContact } = require('./notificationContact');

async function findPurokLeaders(purok, client = prisma) {
  if (!String(purok || '').trim()) return [];
  return client.admin.findMany({
    where: { role: 'Purok Leader', active: true, purok: { equals: String(purok).trim(), mode: 'insensitive' } },
    select: { id: true, fullName: true, contactNumber: true, notifyEmail: true, sessionVersion: true },
    orderBy: { id: 'asc' },
  });
}

const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));

function buildMessage({ leaderName, residentName, purok, documentTypes, atCounter, approveLink, portal }) {
  const docs = documentTypes.length === 1 ? documentTypes[0] : documentTypes.length + ' documents';
  const sms = 'Hi ' + leaderName + ', ' + residentName + ' of ' + purok + ' is requesting ' + docs + ' and needs your purok clearance approval.' +
    (atCounter ? ' The resident is waiting at the barangay office.' : '') +
    ' Please review it in the iRequestDologon portal. -Brgy. Dologon';
  const review = approveLink || (portal ? portal + '/login' : null);
  return {
    sms,
    subject: (atCounter ? 'Resident waiting at the office ? approval needed (' : 'Purok clearance approval needed (') + purok + ')',
    text: sms + (review ? '\n' + (approveLink ? 'Review and approve' : 'Sign in to review') + ': ' + review : ''),
    html: '<p>Dear <strong>' + escapeHtml(leaderName) + '</strong>,</p>' +
      '<p><strong>' + escapeHtml(residentName) + '</strong> of <strong>' + escapeHtml(purok) + '</strong> has requested ' +
      '<strong>' + escapeHtml(docs) + '</strong> and is waiting on your purok clearance approval.</p>' +
      (atCounter ? '<p><strong>This request was made at the barangay office and the resident is waiting.</strong></p>' : '') +
      (review ? '<p><a href="' + escapeHtml(review) + '" style="display:inline-block;background:#156D07;color:#fff;padding:10px 22px;border-radius:8px;text-decoration:none;font-weight:700">' +
        (approveLink ? 'Review &amp; Approve' : 'Sign in to review') + '</a></p>' : '<p>Please open the iRequestDologon portal to review and approve it.</p>') +
      '<p style="color:#888;font-size:12px">Barangay Dologon &ndash; iRequestDologon</p>',
  };
}

// Request controllers launch this after responding. Await all channel results
// here so a successful request is never confused with a successful delivery.
async function notifyPurokLeader({ userId, documentTypes = [], channel, sendSms, sendEmail }, client = prisma) {
  try {
    const profile = await client.verificationProfile.findUnique({ where: { userId }, select: { purok: true, fullName: true } });
    if (!profile?.purok) return { notified: false, reason: 'no_purok' };
    const leaders = await findPurokLeaders(profile.purok, client);
    if (!leaders.length) return { notified: false, reason: 'no_leader', purok: profile.purok };
    const portal = portalUrl();
    const deliveries = [];
    // All active assigned leaders already share the same approval queue.
    // Notify each; a duplicate without an inbox must not hide another leader.
    for (const leader of leaders) {
      const phone = notificationContact({ contactNumber: leader.contactNumber }).data?.contactNumber;
      const mailTo = notificationContact({ notifyEmail: leader.notifyEmail }).data?.notifyEmail;
      const link = portal && buildLink(portal, leader.id, leader.sessionVersion);
      const msg = buildMessage({ leaderName: leader.fullName || 'Purok Leader', residentName: profile.fullName || 'A resident', purok: profile.purok, documentTypes: documentTypes.filter(Boolean), atCounter: channel === 'kiosk', approveLink: link, portal });
      if (mailTo && !link) console.warn('[purok-notify] approval link unavailable; check PORTAL_URL, APPROVE_LINK_SECRET and account session version');
      const delivery = { leaderId: leader.id, reachable: Boolean(phone || mailTo) };
      await Promise.all([
        ['inApp', () => client.notification.create({ data: { adminId: leader.id, message: msg.sms } })],
        ['sms', sendSms && phone ? () => sendSms(phone, msg.sms) : null],
        ['email', sendEmail && mailTo ? () => sendEmail({ to: mailTo, subject: msg.subject, html: msg.html, text: msg.text }) : null],
      ].map(async ([name, send]) => {
        if (!send) { delivery[name] = { status: 'skipped' }; return; }
        try {
          const result = await send();
          if (result?.message?.status === 'failed') throw Object.assign(new Error('SMS rejected'), { code: 'SMS_REJECTED' });
          delivery[name] = { status: name === 'inApp' ? 'saved' : 'accepted', reference: result?.messageId || result?.message?.reference_id || null };
        } catch (error) {
          delivery[name] = { status: 'failed', code: error.code || 'DELIVERY_FAILED' };
          console.error('[purok-notify] ' + name + ' failed for leader ' + leader.id + ': ' + delivery[name].code);
        }
      }));
      deliveries.push(delivery);
    }
    const notified = deliveries.some(d => [d.inApp, d.sms, d.email].some(c => ['saved', 'accepted'].includes(c.status)));
    return { notified, ...(notified ? {} : { reason: 'delivery_failed' }), reachable: deliveries.some(d => d.reachable), purok: profile.purok, deliveries };
  } catch (error) {
    console.error('[purok-notify] failed:', error.code || 'NOTIFICATION_FAILED');
    return { notified: false, reason: 'error' };
  }
}

module.exports = { findPurokLeaders, notifyPurokLeader };
