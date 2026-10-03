const crypto = require('node:crypto');
const { STATUS, requestStatus } = require('./requestStatus');
const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };
const includeOwner = { select: { id: true, username: true, email: true, contactNumber: true, verificationProfile: true } };

// Both admin entry points use the same transitions and completion transaction.
async function transitionRequest(prisma, id, input, include = {}) {
  const requested = String(input || '').trim();
  const target = ['Completed', 'Ready'].includes(requested) ? STATUS.ready : requested;
  if (![STATUS.processing, STATUS.printing, STATUS.ready, STATUS.rejected].includes(target)) fail(400, 'Invalid request status.');
  return prisma.$transaction(async (tx) => {
    const relations = { user: includeOwner, ...include, completedDocuments: true };
    const current = await tx.request.findUnique({ where: { id }, include: relations });
    if (!current) fail(404, 'Request not found');
    const stage = requestStatus(current);
    if (stage === target && target === STATUS.ready) return { request: current, newlyReady: false };
    const transitions = {
      [STATUS.pending]: [STATUS.processing, STATUS.printing, STATUS.rejected],
      [STATUS.processing]: [STATUS.printing, STATUS.rejected],
      [STATUS.printing]: [STATUS.ready, STATUS.rejected],
    };
    if (!transitions[stage]?.includes(target)) fail(400, `Cannot change a ${stage} request to ${target}.`);
    if (target !== STATUS.rejected && !['paid', 'free'].includes(String(current.paymentStatus).toLowerCase())) fail(400, 'Payment is required before this document can be processed or printed.');
    const changed = await tx.request.updateMany({
      where: { id, status: current.status, paymentStatus: current.paymentStatus, purokLeaderStatus: current.purokLeaderStatus },
      data: { status: target },
    });
    if (changed.count !== 1) fail(409, 'This request changed. Refresh and try again.');
    let newlyReady = false;
    if (target === STATUS.ready) {
      const profile = current.user?.verificationProfile;
      const claimCode = 'CLM-' + crypto.randomBytes(4).toString('hex').toUpperCase();
      await tx.completedDocument.create({ data: {
        requestId: id, userId: current.userId, documentType: current.documentType,
        purpose: current.purpose, claimCode, claimStatus: 'pending', completedAt: new Date(),
        fullName: profile?.fullName || current.user?.username || null,
        age: profile?.age ?? null, purok: profile?.purok || (profile?.address || '').split(',')[0].replace(/^Purok\s+/i, '').trim(),
        address: profile?.address || '',
      } });
      await tx.request.update({ where: { id }, data: { claimCode } });
      newlyReady = true;
    }
    return { request: await tx.request.findUnique({ where: { id }, include: relations }), newlyReady };
  });
}

async function setClaimStatus(prisma, id, input) {
  const claimStatus = String(input || '').trim().toLowerCase();
  if (!['pending', 'claimed'].includes(claimStatus)) fail(400, 'Claim status must be pending or claimed.');
  return prisma.$transaction(async (tx) => {
    const original = await tx.completedDocument.findUnique({ where: { id }, include: { request: true } });
    if (!original) fail(404, 'Record not found');
    if (original.requestId) {
      // Serialize handovers and completion against the same request row.
      const locked = await tx.request.updateMany({ where: { id: original.requestId, status: original.request.status }, data: { status: original.request.status } });
      if (!locked.count) fail(409, 'This request changed. Refresh and try again.');
      if (original.request.status === STATUS.rejected || original.request.purokLeaderStatus === 'rejected') fail(400, 'A rejected request cannot be released.');
    }
    const doc = await tx.completedDocument.findUnique({ where: { id } });
    const data = { claimStatus, claimedAt: claimStatus === 'claimed' ? (doc.claimedAt || new Date()) : null };
    if (doc.requestId) {
      await tx.completedDocument.updateMany({ where: { requestId: doc.requestId }, data });
      await tx.request.update({ where: { id: doc.requestId }, data: { status: claimStatus === 'claimed' ? STATUS.claimed : STATUS.ready } });
    } else {
      await tx.completedDocument.update({ where: { id }, data });
    }
    return tx.completedDocument.findUnique({ where: { id }, include: { request: true } });
  });
}

module.exports = { transitionRequest, setClaimStatus };
