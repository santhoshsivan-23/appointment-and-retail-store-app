require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initDatabase, getDatabaseStatus } = require('./config/db');
const authRoutes = require('./routes/auth');
const staffRoutes = require('./routes/staff');
const customerRoutes = require('./routes/customers');
const categoryRoutes = require('./routes/categories');
const productRoutes = require('./routes/products');
const appointmentRoutes = require('./routes/appointments');
const salesRoutes = require('./routes/sales');

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

// API Routes (supports both /api/* and /*)
app.use('/api/auth', authRoutes);
app.use('/auth', authRoutes);
app.use('/api/staff', staffRoutes);
app.use('/staff', staffRoutes);
app.use('/api/customers', customerRoutes);
app.use('/customers', customerRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/categories', categoryRoutes);
app.use('/api/products', productRoutes);
app.use('/products', productRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/appointments', appointmentRoutes);
app.use('/api/sales', salesRoutes);
app.use('/sales', salesRoutes);

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
      auth: '/api/auth (register, login, me)',
      staff: '/api/staff (list, create, update, delete)',
      customers: '/api/customers (list, walk-in, create)',
      categories: '/api/categories (list, create, update, delete)',
      products: '/api/products (list, create, update, delete)',
      appointments: '/api/appointments (list, create, status, update, delete, check-conflict)',
      sales: '/api/sales (list, create by id)',
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
    console.log(`👥 Staff API:        http://localhost:${PORT}/api/staff`);
    console.log(`👤 Customer API:     http://localhost:${PORT}/api/customers`);
    console.log(`🗂️ Categories API:   http://localhost:${PORT}/api/categories`);
    console.log(`📦 Products API:     http://localhost:${PORT}/api/products`);
    console.log(`📅 Appointments API: http://localhost:${PORT}/api/appointments`);
    console.log(`💰 Sales API:         http://localhost:${PORT}/api/sales`);
    console.log('====================================================');
  });
}

startServer();
