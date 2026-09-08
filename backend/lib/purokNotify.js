const prisma = require('./prisma');

/**
 * Tells a Purok Leader that a request is waiting for their approval.
 *
 * Nothing did this before: a leader only discovered pending requests by logging
 * in and looking. That is tolerable when approval can wait days, and useless
 * when a resident is standing at the kiosk.
 *
 * Three channels, best-effort and independent — one failing does not stop the
 * others, and none of them can fail the request that triggered them. Delivery
 * is deliberately fire-and-forget: a resident must never see a request rejected
 * because an SMS gateway was down.
 */

// Finds the Purok Leader account responsible for a purok.
async function findPurokLeader(purok, client = prisma) {
  if (!purok) return null;
  return client.admin.findFirst({
    where: {
      role: 'Purok Leader',
      purok: { equals: String(purok).trim(), mode: 'insensitive' },
    },
  });
}

function buildMessage({ leaderName, residentName, purok, documentTypes, atCounter }) {
  const docs = documentTypes.length === 1 ? documentTypes[0] : `${documentTypes.length} documents`;
  const urgency = atCounter
    ? ' The resident is waiting at the barangay office.'
    : '';
  return {
    sms:
      `Hi ${leaderName}, ${residentName} of ${purok} is requesting ${docs} and needs your purok clearance approval.` +
      `${urgency} Please review it in the iRequestDologon portal. -Brgy. Dologon`,
    subject: atCounter
      ? `Resident waiting at the office — approval needed (${purok})`
      : `Purok clearance approval needed (${purok})`,
    html: `
      <p>Dear <strong>${leaderName}</strong>,</p>
      <p><strong>${residentName}</strong> of <strong>${purok}</strong> has requested
      <strong>${docs}</strong> and is waiting on your purok clearance approval.</p>
      ${atCounter
        ? '<p style="color:#A32B1E"><strong>This request was made at the barangay office and the resident is waiting.</strong></p>'
        : ''}
      <p>Please open the iRequestDologon portal to review and approve it.</p>
      <p style="color:#888;font-size:12px">Barangay Dologon &ndash; iRequestDologon</p>`,
  };
}

/**
 * @param {object}   opts
 * @param {string}   opts.userId          the resident who made the request
 * @param {string[]} opts.documentTypes   what they asked for
 * @param {string}   [opts.channel]       'kiosk' marks the resident as waiting
 * @param {Function} [opts.sendSms]       (to, message) => Promise
 * @param {Function} [opts.sendEmail]     ({ to, subject, html }) => Promise
 * @returns {Promise<{notified: boolean, reason?: string}>} never rejects
 */
async function notifyPurokLeader(opts, client = prisma) {
  const { userId, documentTypes = [], channel, sendSms, sendEmail } = opts;
  try {
    const profile = await client.verificationProfile.findUnique({
      where: { userId },
      select: { purok: true, fullName: true },
    });
    if (!profile?.purok) {
      console.warn('[purok-notify] resident has no purok on file — cannot route approval');
      return { notified: false, reason: 'no_purok' };
    }

    const leader = await findPurokLeader(profile.purok, client);
    if (!leader) {
      // Expected for now: 19 of 21 puroks have no Purok Leader account, so
      // their residents' requests cannot be approved by anyone. Logged loudly
      // because it is an onboarding gap, not a code fault.
      console.warn(
        `[purok-notify] no Purok Leader account for "${profile.purok}" — ` +
          'request cannot be approved until one exists'
      );
      return { notified: false, reason: 'no_leader', purok: profile.purok };
    }

    const atCounter = channel === 'kiosk';
    const msg = buildMessage({
      leaderName: leader.fullName || 'Purok Leader',
      residentName: profile.fullName || 'A resident',
      purok: profile.purok,
      documentTypes: documentTypes.filter(Boolean),
      atCounter,
    });

    // In-app notification — the only channel that cannot bounce.
    await client.notification
      .create({ data: { adminId: leader.id, message: msg.sms } })
      .catch((e) => console.error('[purok-notify] in-app notification failed:', e.message));

    if (sendSms && leader.contactNumber) {
      Promise.resolve(sendSms(leader.contactNumber, msg.sms))
        .then(() => console.log(`[purok-notify] SMS sent to ${leader.fullName}`))
        .catch((e) => console.error('[purok-notify] SMS failed:', e.message));
    } else if (sendSms) {
      console.warn(`[purok-notify] ${leader.fullName} has no contact number — SMS skipped`);
    }

    // `email` is the login identifier and sits on @dologon.gov.ph, a domain
    // with no MX record — mail to it is accepted by the relay and then bounces.
    // Only notifyEmail is a real inbox.
    const mailTo = leader.notifyEmail || null;
    if (sendEmail && mailTo) {
      Promise.resolve(sendEmail({ to: mailTo, subject: msg.subject, html: msg.html }))
        .then(() => console.log(`[purok-notify] email sent to ${mailTo}`))
        .catch((e) => console.error('[purok-notify] email failed:', e.message));
    } else if (sendEmail) {
      console.warn(
        `[purok-notify] ${leader.fullName} has no reachable email — set notifyEmail ` +
          `(login address ${leader.email} cannot receive mail)`
      );
    }

    const reachable = Boolean(leader.contactNumber) || Boolean(mailTo);
    if (!reachable) {
      console.warn(
        `[purok-notify] ${leader.fullName} has no phone number and no notifyEmail — ` +
          'they will only see this by logging in'
      );
    }

    return { notified: true, reachable, leader: leader.fullName, purok: profile.purok };
  } catch (err) {
    // Swallowed on purpose — see the note at the top of this file.
    console.error('[purok-notify] failed:', err.message);
    return { notified: false, reason: 'error' };
  }
}

module.exports = { findPurokLeader, notifyPurokLeader };
