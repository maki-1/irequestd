const prisma = require('../lib/prisma');
const { isUuid } = require('../lib/ids');
const { verifyToken, requireSession } = require('../lib/accountLifecycle');

module.exports = async function (req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'No token, authorization denied' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = verifyToken(token, 'resident');
    if (!isUuid(decoded.id)) return res.status(401).json({ message: 'Invalid token' });
    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      select: { id: true, username: true, active: true, deletedAt: true, sessionVersion: true, contactVerified: true },
    });
    if (!requireSession(user, decoded, res)) return;
    if (!user.contactVerified) {
      return res.status(403).json({ message: 'Verify your contact first.', requiresVerification: true, userId: user.id });
    }
    req.user = user;
    next();
  } catch {
    res.status(401).json({ message: 'Token is not valid' });
  }
};
