const mongoose = require('mongoose');

const verificationProfileSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    // Step 1 – Demographic
    fullName: { type: String, default: '' },
    address: { type: String, default: '' },
    age: { type: Number, default: null },
    gender: { type: String, default: '' },
    yearsAtAddress: { type: String, default: '' },
    motherName: { type: String, default: '' },
    fatherName: { type: String, default: '' },

    // Step 2 – Education
    educationLevel: { type: String, default: '' },
    school: { type: String, default: '' },
    yearGraduated: { type: String, default: '' },
    course: { type: String, default: '' },
    educationCertificate: { type: String, default: '' }, // filename

    // Step 3 – ID + Face
    idType: { type: String, default: '' },   // 'primary' | 'secondary'
    idName: { type: String, default: '' },
    idFront: { type: String, default: '' },  // filename
    idBack: { type: String, default: '' },   // filename
    facePhoto: { type: String, default: '' }, // filename

    // Progress tracking
    currentStep: { type: Number, default: 1 }, // 1, 2, 3

    // Status
    status: {
      type: String,
      enum: ['draft', 'pending', 'approved', 'rejected'],
      default: 'draft',
    },
    rejectionReason: { type: String, default: '' },
    submittedAt: { type: Date, default: null },
    reviewedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('VerificationProfile', verificationProfileSchema);
