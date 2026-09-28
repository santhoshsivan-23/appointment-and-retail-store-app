const express = require('express');
const router = express.Router();
const { getCustomers, createCustomer } = require('../config/db');

// List / Search customers
router.get('/', async (req, res) => {
  try {
    const { search } = req.query;
    const businessId = req.business ? req.business.id : 1;
    const customers = await getCustomers(businessId, search);
    res.json({ success: true, count: customers.length, data: customers });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Create Customer (Normal or Walk-in)
router.post('/', async (req, res) => {
  try {
    const { name, phone, email, is_walk_in, notes } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Customer name is required.' });
    }
    if (!phone || !phone.trim()) {
      return res.status(400).json({ success: false, message: 'Customer phone number is required.' });
    }
    const businessId = req.business ? req.business.id : 1;
    const customer = await createCustomer({
      business_id: businessId,
      name,
      phone,
      email: email || '',
      is_walk_in: Boolean(is_walk_in),
      notes: notes || '',
    });
    res.status(201).json({
      success: true,
      message: is_walk_in ? 'Walk-in customer registered' : 'Customer created successfully',
      data: customer,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
