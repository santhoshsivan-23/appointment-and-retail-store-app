const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/settings?business_id=X
router.get('/', async (req, res) => {
  try {
    const businessId = req.query.business_id || req.body?.business_id || 1;
    const settings = await db.getSettings(businessId);
    res.json({
      success: true,
      data: settings,
    });
  } catch (err) {
    console.error('Error fetching settings:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve settings.',
      error: err.message,
    });
  }
});

// Update settings helper
const handleUpdateSettings = async (req, res) => {
  try {
    const businessId = req.body?.business_id || req.query.business_id || 1;
    const updated = await db.updateSettings(businessId, req.body || {});
    res.json({
      success: true,
      message: 'Settings updated successfully.',
      data: updated,
    });
  } catch (err) {
    console.error('Error updating settings:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to update settings.',
      error: err.message,
    });
  }
};

// PUT /api/settings
router.put('/', handleUpdateSettings);

// POST /api/settings (for clients sending POST)
router.post('/', handleUpdateSettings);

module.exports = router;
