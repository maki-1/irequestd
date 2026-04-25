const mongoose = require('mongoose');

// Maps to the existing `completed_documents` collection in MongoDB.
// claimStatus: 'Pending' = ready for pickup, 'Claimed' = already collected.
const completedDocumentSchema = new mongoose.Schema(
  {
    user:         { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    userId:       { type: String },          // fallback if stored as string
    requestId:    { type: mongoose.Schema.Types.ObjectId, ref: 'Request' },
    documentType: { type: String },
    claimCode:    { type: String },
    claimStatus:  { type: String },          // 'Pending' | 'Claimed'
    completedAt:  { type: Date },
  },
  {
    collection: 'completed_documents',       // exact collection name
    strict: false,                           // allow any extra fields the admin stores
    timestamps: true,
  }
);

module.exports = mongoose.model('CompletedDocument', completedDocumentSchema);
