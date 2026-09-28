require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initDatabase, getDatabaseStatus } = require('./config/db');
const authRoutes = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logger for easy debugging
app.use((req, res, next) => {
  const timestamp = new Date().toISOString().split('T')[1].slice(0, 8);
  console.log(`[${timestamp}] ${req.method} ${req.originalUrl}`);
  next();
});

// API Routes
app.use('/api/auth', authRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    message: 'Appointment & Hotel Booking Backend is up and running!',
    database: getDatabaseStatus(),
    timestamp: new Date().toISOString(),
  });
});

// Root welcome route
app.get('/', (req, res) => {
  res.json({
    name: 'Appointment & Hotel Booking Management API',
    version: '1.0.0',
    endpoints: {
      health: 'GET /api/health',
      register: 'POST /api/auth/register',
      login: 'POST /api/auth/login',
      profile: 'GET /api/auth/me (Bearer Token required)',
    },
  });
});

// 404 Route Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// Start Server
async function startServer() {
  await initDatabase();

  app.listen(PORT, () => {
    console.log('====================================================');
    console.log(`🚀 Server listening on http://localhost:${PORT}`);
    console.log(`📡 Health Check:     http://localhost:${PORT}/api/health`);
    console.log(`📝 Register API:     POST http://localhost:${PORT}/api/auth/register`);
    console.log(`🔑 Login API:        POST http://localhost:${PORT}/api/auth/login`);
    console.log('====================================================');
  });
}

startServer();
