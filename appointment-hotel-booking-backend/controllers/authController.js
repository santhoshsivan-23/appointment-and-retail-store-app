const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const {
  findBusinessByEmail,
  findBusinessById,
  createBusiness,
} = require('../config/db');

// Helper to generate JWT token
function generateToken(payload) {
  const secret = process.env.JWT_SECRET || 'super_secret_jwt_key_appointment_hotel_2026';
  const expiresIn = process.env.JWT_EXPIRES_IN || '7d';
  return jwt.sign(payload, secret, { expiresIn });
}

// Email validator
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Register Business
async function registerBusiness(req, res) {
  try {
    const {
      business_name,
      business_type,
      owner_name,
      email,
      phone,
      password,
      address,
      city,
      country,
      description,
    } = req.body;

    // Field Validations
    if (!business_name || !business_name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Business name is required.',
      });
    }

    if (!business_type || !business_type.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Business type is required (e.g., Hotel, Appointment/Salon, etc.).',
      });
    }

    if (!owner_name || !owner_name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Owner/Contact person name is required.',
      });
    }

    if (!email || !isValidEmail(email.trim())) {
      return res.status(400).json({
        success: false,
        message: 'A valid email address is required.',
      });
    }

    if (!phone || !phone.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required.',
      });
    }

    if (!password || password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long.',
      });
    }

    // Check if email already registered
    const existing = await findBusinessByEmail(email);
    if (existing) {
      return res.status(409).json({
        success: false,
        message: 'A business with this email already exists. Please log in or use another email.',
      });
    }

    // Hash password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // Save business
    const newBusiness = await createBusiness({
      business_name,
      business_type,
      owner_name,
      email,
      phone,
      password: hashedPassword,
      address: address || '',
      city: city || '',
      country: country || '',
      description: description || '',
    });

    // Generate Token
    const token = generateToken({
      id: newBusiness.id,
      email: newBusiness.email,
      business_name: newBusiness.business_name,
    });

    return res.status(201).json({
      success: true,
      message: 'Business registered successfully!',
      token,
      business: newBusiness,
    });
  } catch (error) {
    console.error('Error in registerBusiness:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while registering business.',
      error: error.message,
    });
  }
}

// Login Business
async function loginBusiness(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required.',
      });
    }

    const business = await findBusinessByEmail(email);
    if (!business) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    const isMatch = await bcrypt.compare(password, business.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    const token = generateToken({
      id: business.id,
      email: business.email,
      business_name: business.business_name,
    });

    const { password: _, ...safeBusiness } = business;

    return res.status(200).json({
      success: true,
      message: 'Login successful!',
      token,
      business: safeBusiness,
    });
  } catch (error) {
    console.error('Error in loginBusiness:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while logging in.',
      error: error.message,
    });
  }
}

// Get Current Logged-in Business
async function getMe(req, res) {
  try {
    const businessId = req.business.id;
    const business = await findBusinessById(businessId);

    if (!business) {
      return res.status(404).json({
        success: false,
        message: 'Business not found.',
      });
    }

    return res.status(200).json({
      success: true,
      business,
    });
  } catch (error) {
    console.error('Error in getMe:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error retrieving business profile.',
      error: error.message,
    });
  }
}

module.exports = {
  registerBusiness,
  loginBusiness,
  getMe,
};
