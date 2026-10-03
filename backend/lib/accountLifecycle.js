// Canonical policy. Sync this file to the mobile backend with
// scripts/sync-account-lifecycle.cjs; do not edit the vendored copy separately.
const jwt = require('jsonwebtoken');

const isAccountActive = (account) => !!account && account.active === true && !account.deletedAt;
const disabled = { code: 'ACCOUNT_DISABLED', message: 'This account is disabled. Please contact the barangay office.' };
const revoked = { code: 'SESSION_REVOKED', message: 'Your session has ended. Please sign in again.' };

function requireActive(account, res) {
  if (isAccountActive(account)) return true;
  res.status(403).json(disabled);
  return false;
}

function requireSession(account, claims, res) {
  if (!account) {
    res.status(401).json(revoked);
    return false;
  }
  if (!requireActive(account, res)) return false;
  if (!Number.isSafeInteger(claims.sessionVersion) || claims.sessionVersion < 0 ||
      claims.sessionVersion !== account.sessionVersion) {
    res.status(401).json(revoked);
    return false;
  }
  return true;
}

function secret() {
  if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET must be configured');
  return process.env.JWT_SECRET;
}

function signToken(account, accountType, purpose = 'access') {
  if (!isAccountActive(account) || !Number.isSafeInteger(account.sessionVersion)) {
    throw new Error('Cannot issue a token for an inactive or unmigrated account');
  }
  if (!['resident', 'staff'].includes(accountType) || !['access', 'reset'].includes(purpose)) {
    throw new Error('Invalid token scope');
  }
  return jwt.sign({
    id: account.id, accountType, purpose, sessionVersion: account.sessionVersion,
    role: accountType === 'resident' ? 'resident' : account.role,
    ...(accountType === 'staff' ? { isAdmin: true } : {}),
  }, secret(), {
    algorithm: 'HS256',
    expiresIn: purpose === 'reset' ? '15m' : (process.env.JWT_EXPIRES_IN || (accountType === 'staff' ? '8h' : '7d')),
  });
}

function verifyToken(token, accountType, purpose = 'access') {
  const claims = jwt.verify(token, secret(), { algorithms: ['HS256'] });
  if (claims.purpose !== purpose || !['resident', 'staff'].includes(claims.accountType) ||
      (accountType && claims.accountType !== accountType) ||
      !Number.isSafeInteger(claims.sessionVersion) || claims.sessionVersion < 0) {
    throw new Error('Invalid token scope or legacy session');
  }
  return claims;
}

function residentRevocationData() {
  return {
    sessionVersion: { increment: 1 },
    resetToken: null, resetTokenExpires: null,
    otp: null, otpExpires: null, otpType: null, otpAttempts: 0,
  };
}

// Compare-and-swap makes a reset single use, including simultaneous requests.
// Both OTP stores are cleared so an older recovery code cannot undo the change.
async function changeResidentPassword(prisma, account, password, extraWhere = {}) {
  return prisma.$transaction(async (tx) => {
    const { count } = await tx.user.updateMany({
      where: { ...extraWhere, id: account.id, active: true, deletedAt: null, sessionVersion: account.sessionVersion },
      data: { password, ...residentRevocationData() },
    });
    if (count) await tx.otpCode.deleteMany({ where: { userId: account.id } });
    return count === 1;
  });
}

module.exports = {
  isAccountActive, requireActive, requireSession, signToken, verifyToken,
  residentRevocationData, changeResidentPassword, revoked,
};
