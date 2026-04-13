const cloudinary = require('cloudinary').v2;
const multer = require('multer');
const { Readable } = require('stream');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Custom multer storage engine for Cloudinary v2
function cloudinaryStorage(options) {
  return {
    _handleFile(req, file, cb) {
      const params = typeof options.params === 'function'
        ? options.params(req, file)
        : options.params;

      const uploadStream = cloudinary.uploader.upload_stream(params, (err, result) => {
        if (err) return cb(err);
        cb(null, {
          fieldname: file.fieldname,
          originalname: file.originalname,
          path: result.secure_url,       // full CDN URL
          filename: result.public_id,
          size: result.bytes,
          mimetype: file.mimetype,
        });
      });

      const readable = new Readable();
      readable._read = () => {};
      file.stream.pipe(uploadStream);
    },
    _removeFile(req, file, cb) {
      if (file.filename) {
        cloudinary.uploader.destroy(file.filename, cb);
      } else {
        cb(null);
      }
    },
  };
}

const avatarStorage = cloudinaryStorage({
  params: {
    folder: 'irequestd/avatars',
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [{ width: 400, height: 400, crop: 'fill', gravity: 'face' }],
  },
});

const idDocStorage = cloudinaryStorage({
  params: {
    folder: 'irequestd/id_docs',
    allowed_formats: ['jpg', 'jpeg', 'png', 'pdf'],
    resource_type: 'auto',
  },
});

const faceStorage = cloudinaryStorage({
  params: {
    folder: 'irequestd/faces',
    allowed_formats: ['jpg', 'jpeg', 'png'],
    transformation: [{ width: 600, height: 600, crop: 'fill', gravity: 'face' }],
  },
});

const uploadAvatar = multer({ storage: avatarStorage });
const uploadIdDoc  = multer({ storage: idDocStorage });
const uploadFace   = multer({ storage: faceStorage });

module.exports = { cloudinary, uploadAvatar, uploadIdDoc, uploadFace };
