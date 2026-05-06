require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');

const app = express();

// Connect to MongoDB
connectDB();

// Middleware
app.use(cors());
app.use(express.json());

// Static file serving for uploads
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/requests', require('./routes/requests'));
app.use('/api/payment', require('./routes/payment'));
app.use('/api/verification', require('./routes/verification'));
app.use('/api/admin', require('./routes/admin'));

// Serve admin portal static files
app.use('/admin', express.static(path.join(__dirname, '../admin')));

// Health check
app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

// PayMongo redirect landing pages
const paymentHtml = (title, message, emoji) => `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>${title}</title>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
      background:#f4f6f4;display:flex;align-items:center;justify-content:center;
      min-height:100vh;padding:24px}
    .card{background:#fff;border-radius:20px;padding:40px 32px;text-align:center;
      max-width:360px;width:100%;box-shadow:0 4px 24px rgba(0,0,0,.08)}
    .emoji{font-size:56px;margin-bottom:20px}
    h1{font-size:22px;font-weight:800;color:#1a1a1a;margin-bottom:10px}
    p{font-size:15px;color:#555;line-height:1.5}
    .btn{margin-top:24px;display:inline-block;padding:12px 28px;background:#1a6b1a;
      color:#fff;border:none;border-radius:32px;font-size:15px;font-weight:700;
      cursor:pointer;text-decoration:none}
    .note{margin-top:14px;font-size:12px;color:#bbb}
  </style>
</head>
<body>
  <div class="card">
    <div class="emoji">${emoji}</div>
    <h1>${title}</h1>
    <p>${message}</p>
    <button class="btn" onclick="window.close()">Close Tab</button>
    <p class="note">Closing automatically…</p>
  </div>
  <script>
    // Attempt auto-close immediately; browsers may block if not opened via script
    window.close();
    // Retry once after a short delay as a fallback
    setTimeout(function(){ window.close(); }, 800);
  </script>
</body>
</html>`;

app.get('/payment/success', (_req, res) => {
  res.send(paymentHtml(
    'Payment Received',
    'Your payment was successful. Your document request is now being processed.',
    '✅'
  ));
});

app.get('/payment/cancel', (_req, res) => {
  res.send(paymentHtml(
    'Payment Cancelled',
    'Your payment was not completed. You can try again from the iRequestD app.',
    '↩️'
  ));
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
