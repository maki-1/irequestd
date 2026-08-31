const bcrypt = require('bcryptjs');

// Mongoose hashed passwords in a pre('save') hook and compared them through a
// schema method. Prisma has neither, so both live here and every write path
// that touches a password calls hashPassword explicitly.
const ROUNDS = 10;

function hashPassword(plain) {
  return bcrypt.hash(plain, ROUNDS);
}

function comparePassword(plain, hashed) {
  return bcrypt.compare(plain, hashed);
}

module.exports = { hashPassword, comparePassword };
