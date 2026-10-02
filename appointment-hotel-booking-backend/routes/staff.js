const express = require('express');
const router = express.Router();
const {
  getStaffList,
  getStaffById,
  createStaff,
  updateStaff,
  deleteStaff,
} = require('../config/db');

// List staff with optional search & historical inclusion
router.get('/', async (req, res) => {
  try {
    const { search, include_deleted } = req.query;
    const businessId = req.business ? req.business.id : 1;
    const staff = await getStaffList(businessId, search, include_deleted === 'true');
    res.json({ success: true, count: staff.length, data: staff });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Single staff details
router.get('/:id', async (req, res) => {
  try {
    const staff = await getStaffById(req.params.id);
    if (!staff) return res.status(404).json({ success: false, message: 'Staff member not found' });
    res.json({ success: true, data: staff });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Create staff
router.post('/', async (req, res) => {
  try {
    const { name, email, phone, role, color_code, image } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Staff name is required.' });
    }
    const businessId = req.business ? req.business.id : 1;
    const staff = await createStaff({
      business_id: businessId,
      name,
      email,
      phone,
      role: role || 'Staff',
      color_code: color_code || '#B42907',
      image: image || null,
    });
    res.status(201).json({ success: true, message: 'Staff member created successfully', data: staff });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Update staff
router.put('/:id', async (req, res) => {
  try {
    const updated = await updateStaff(req.params.id, req.body);
    if (!updated) return res.status(404).json({ success: false, message: 'Staff not found' });
    res.json({ success: true, message: 'Staff updated successfully', data: updated });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Soft Delete staff (preserves historical references)
router.delete('/:id', async (req, res) => {
  try {
    const ok = await deleteStaff(req.params.id);
    if (!ok) return res.status(404).json({ success: false, message: 'Staff not found' });
    res.json({
      success: true,
      message: 'Staff deleted successfully (deactivated from active scheduling, historical records preserved)',
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
