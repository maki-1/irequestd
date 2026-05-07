const mongoose = require('mongoose');

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
  },
  { timestamps: true }
);

// Auto-generate OR number before first save
requestSchema.pre('save', async function (next) {
  if (!this.orNumber) {
    const count = await this.constructor.countDocuments();
    const year = new Date().getFullYear();
    this.orNumber = `OR-${year}-${String(count + 1).padStart(5, '0')}`;
  }
  next();
});

module.exports = mongoose.model('Request', requestSchema);
