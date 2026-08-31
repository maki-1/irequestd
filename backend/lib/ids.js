const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Mongoose turned a malformed id into a CastError that the route caught as a
// 500. Prisma throws on a non-UUID string instead, so ids coming off the wire
// are checked first and treated as "not found" rather than a server error.
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);

module.exports = { isUuid };
