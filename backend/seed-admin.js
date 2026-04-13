require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

async function seed() {
  console.log('Connecting to MongoDB…');
  console.log('URI:', process.env.MONGO_URI ? '✓ found' : '✗ MONGO_URI missing');

  if (!process.env.MONGO_URI) {
    console.error('ERROR: MONGO_URI not set. Make sure .env exists in the backend folder.');
    process.exit(1);
  }

  await mongoose.connect(process.env.MONGO_URI);
  console.log('Connected.');

  const db = mongoose.connection.db;
  const collection = db.collection('admins');

  const existing = await collection.findOne({ username: 'secretary' });
  if (existing) {
    const hashed = await bcrypt.hash('dologon2024', 10);
    await collection.updateOne({ username: 'secretary' }, { $set: { password: hashed } });
    console.log('✓ Admin password reset');
  } else {
    const hashed = await bcrypt.hash('dologon2024', 10);
    await collection.insertOne({
      username: 'secretary',
      password: hashed,
      name: 'Barangay Secretary',
      role: 'secretary',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    console.log('✓ Admin account created');
  }

  console.log('');
  console.log('  Username : secretary');
  console.log('  Password : dologon2024');
  console.log('  Login at : http://localhost:5000/admin');

  await mongoose.disconnect();
  process.exit(0);
}

seed().catch(err => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
