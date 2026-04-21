const mongoose = require('mongoose');

const documentPriceSchema = new mongoose.Schema(
  {
    documentType: { type: String, required: true, unique: true, trim: true },
    pricecentavos: { type: Number, required: true, min: 0 },
    description: { type: String, trim: true, default: '' },
    updatedBy: { type: String, trim: true, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('DocumentPrice', documentPriceSchema);
