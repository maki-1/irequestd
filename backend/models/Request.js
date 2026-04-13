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
      enum: ['Pick up at Barangay Office', 'Digital (Email)'],
      required: true,
    },
    status: {
      type: String,
      enum: ['Pending', 'Processing', 'Ready', 'Rejected'],
      default: 'Pending',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Request', requestSchema);
