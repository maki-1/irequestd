const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Storage for user avatar uploads
const avatarStorage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder:         'irequestd/avatars',
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [{ width: 400, height: 400, crop: 'fill', gravity: 'face' }],
  },
});

// Storage for ID verification document uploads
const idDocStorage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder:          'irequestd/id_docs',
    allowed_formats: ['jpg', 'jpeg', 'png', 'pdf'],
    resource_type:   'auto',
  },
});

// Storage for face recognition photos
const faceStorage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder:          'irequestd/faces',
    allowed_formats: ['jpg', 'jpeg', 'png'],
    transformation: [{ width: 600, height: 600, crop: 'fill', gravity: 'face' }],
  },
});

const uploadAvatar  = multer({ storage: avatarStorage });
const uploadIdDoc   = multer({ storage: idDocStorage });
const uploadFace    = multer({ storage: faceStorage });

module.exports = { cloudinary, uploadAvatar, uploadIdDoc, uploadFace };
