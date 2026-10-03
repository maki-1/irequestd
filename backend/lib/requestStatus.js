// Canonical request/read-model contract, vendored by the mobile backend.
const STATUS = Object.freeze({
  pending: 'Pending', processing: 'Processing', printing: 'Printing',
  ready: 'Ready for Pickup', claimed: 'Claimed', rejected: 'Rejected',
});
const lower = (value) => String(value || '').trim().toLowerCase();
const isClaimed = (doc) => !!doc.claimedAt || ['claimed', 'complete', 'completed'].includes(lower(doc.claimStatus)) || lower(doc.request?.status) === 'claimed';
const isRejected = (request) => lower(request?.status) === 'rejected' || lower(request?.purokLeaderStatus) === 'rejected';

function releaseStatus(doc) {
  if (isClaimed(doc)) return STATUS.claimed;
  if (isRejected(doc.request)) return STATUS.rejected;
  // Older completion writers omitted claimStatus. A real release row with no
  // handover evidence is still waiting for pickup; a status string alone is not.
  if (['', 'pending', 'ready', 'ready for pickup', 'unclaimed'].includes(lower(doc.claimStatus))) return STATUS.ready;
  return null;
}

function canonicalDocuments(documents) {
  const byRequest = new Map();
  for (const doc of documents) {
    const status = releaseStatus(doc);
    if (![STATUS.ready, STATUS.claimed].includes(status)) continue;
    const shaped = {
      ...doc, status, claimStatus: status === STATUS.claimed ? 'claimed' : 'pending',
      completedAt: doc.completedAt || doc.createdAt,
      ...(doc.request ? { request: { ...doc.request, status } } : {}),
    };
    const key = doc.requestId || doc.id;
    const previous = byRequest.get(key);
    // Historical duplicate releases/reprints are one pickup, and any handover
    // evidence wins over a stale pending duplicate.
    if (!previous || (status === STATUS.claimed && previous.status !== STATUS.claimed)) byRequest.set(key, shaped);
  }
  return [...byRequest.values()];
}

function requestStatus(request) {
  const releases = (request.completedDocuments || []).filter((doc) => !doc.userId || doc.userId === request.userId);
  const documents = releases.map((doc) => ({ ...doc, request }));
  if (lower(request.status) === 'claimed' || documents.some(isClaimed)) return STATUS.claimed;
  if (isRejected(request)) return STATUS.rejected;
  if (documents.some((doc) => releaseStatus(doc) === STATUS.ready)) return STATUS.ready;
  const raw = lower(request.status);
  if (['ready', 'completed', 'ready for pickup', 'printing'].includes(raw)) return STATUS.printing;
  if (raw === 'processing') return STATUS.processing;
  return STATUS.pending;
}

function shapeRequest(request) {
  const { completedDocuments, ...rest } = request;
  return { ...rest, status: requestStatus(request) };
}

const RELEASE_REQUEST_SELECT = {
  id: true, userId: true, status: true, purokLeaderStatus: true,
  documentType: true, purpose: true, paymentStatus: true, orNumber: true, createdAt: true,
};

async function residentDocuments(client, userId) {
  const docs = await client.completedDocument.findMany({
    where: { OR: [{ userId }, { userId: null, request: { userId } }] },
    include: { request: { select: RELEASE_REQUEST_SELECT } },
    orderBy: [{ completedAt: 'desc' }, { createdAt: 'desc' }, { id: 'asc' }],
  });
  // Never expose a release linked to another resident's request.
  return canonicalDocuments(docs.filter((doc) => !doc.request || doc.request.userId === userId));
}

async function residentSummary(prisma, userId) {
  return prisma.$transaction(async (tx) => {
    const requests = await tx.request.findMany({
      where: { userId },
      select: { id: true, userId: true, status: true, purokLeaderStatus: true, completedDocuments: true },
    });
    const documents = await residentDocuments(tx, userId);
    const readyDocuments = documents.filter((doc) => doc.status === STATUS.ready);
    const summary = { total: requests.length, pending: 0, processing: 0, printing: 0, ready: readyDocuments.length, claimed: documents.filter((doc) => doc.status === STATUS.claimed).length, rejected: 0 };
    for (const request of requests) {
      const status = requestStatus(request);
      for (const key of ['pending', 'processing', 'printing', 'rejected']) if (status === STATUS[key]) summary[key]++;
    }
    return { ...summary, readyDocuments };
  }, { isolationLevel: 'RepeatableRead' });
}

module.exports = { STATUS, requestStatus, shapeRequest, releaseStatus, canonicalDocuments, residentDocuments, residentSummary, RELEASE_REQUEST_SELECT };
