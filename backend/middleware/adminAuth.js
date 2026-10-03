const prisma = require('../lib/prisma');
const { isUuid } = require('../lib/ids');
const { verifyToken, requireSession } = require('../lib/accountLifecycle');

module.exports = async (req, res, next) => {
  if (!req.headers.authorization?.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'No token' });
  }
  try {
    const claims = verifyToken(req.headers.authorization.split(' ')[1], 'staff');
    if (!isUuid(claims.id)) return res.status(401).json({ message: 'Invalid token' });
    const admin = await prisma.admin.findUnique({
      where: { id: claims.id },
      select: { id: true, email: true, fullName: true, role: true, purok: true, active: true, sessionVersion: true },
    });
    if (!requireSession(admin, claims, res)) return;
    req.admin = { ...admin, name: admin.fullName, isAdmin: true };
    next();
  } catch {
    res.status(401).json({ message: 'Invalid or expired token' });
  }
};
