const express = require('express');
const router = express.Router();
const {
  registerBusiness,
  loginBusiness,
  getMe,
} = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Public auth routes
router.post('/register', registerBusiness);
router.post('/login', loginBusiness);

// Protected routes
router.get('/me', authenticateToken, getMe);

module.exports = router;
