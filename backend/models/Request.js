const mongoose = require('mongoose');

const counterSchema = new mongoose.Schema({
  _id: String,
  seq: { type: Number, default: 0 },
});
const Counter = mongoose.models.Counter || mongoose.model('Counter', counterSchema);

const requestSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    documentType: {
      type: String,
      enum: ['Barangay Clearance', 'Certificate of Residency', 'Certificate of Indigency'],
      required: true,
    },
    purpose: {
      type: String,
      required: true,
      trim: true,
    },
    additionalDetails: {
      type: String,
      trim: true,
      default: '',
    },
    deliveryMethod: {
      type: String,
      enum: ['Pick up at Barangay Office'],
      required: true,
    },
    status: {
      type: String,
      enum: ['Pending', 'Processing', 'Ready', 'Rejected'],
      default: 'Pending',
    },
    paymentStatus: {
      type: String,
      enum: ['unpaid', 'paid'],
      default: 'unpaid',
    },
    paymentSessionId: { type: String, default: null },
    amountPaid: { type: Number, default: 0 }, // in pesos (PHP)
    orNumber: { type: String, unique: true, sparse: true },
    freeDocumentProof: { type: String, default: '' },
    requestPhoto: { type: String, default: '' },     // Cloudinary URL — camera photo required per request
    controlNumber: { type: String, default: '' },
  },
  { timestamps: true }
);

// Auto-generate OR number before first save using an atomic counter to avoid race conditions
requestSchema.pre('save', async function (next) {
  if (!this.orNumber) {
    const year = new Date().getFullYear();
    const counter = await Counter.findOneAndUpdate(
      { _id: `orNumber-${year}` },
      { $inc: { seq: 1 } },
      { new: true, upsert: true }
    );
    this.orNumber = `OR-${year}-${String(counter.seq).padStart(5, '0')}`;
  }
  next();
});

module.exports = mongoose.model('Request', requestSchema);
