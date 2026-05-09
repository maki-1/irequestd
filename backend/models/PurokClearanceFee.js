const mongoose = require('mongoose');

const purokClearanceFeeSchema = new mongoose.Schema(
  {
    purokName: { type: String, required: true, unique: true, trim: true },
    feecentavos: { type: Number, required: true, min: 0, default: 0 },
    treasurerName: { type: String, trim: true, default: '' },
    purokPresident: { type: String, trim: true, default: '' },
    description: { type: String, trim: true, default: '' },
    updatedBy: { type: String, trim: true, default: '' },
  },
  { timestamps: true, collection: 'purok_clearance_fee' }
);

module.exports = mongoose.model('PurokClearanceFee', purokClearanceFeeSchema);
