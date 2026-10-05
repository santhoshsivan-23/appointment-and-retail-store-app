const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/sales
router.get('/', async (req, res) => {
  try {
    const { appointment_id, customer_id, search, include_appointments } = req.query;
    const filters = {};
    if (appointment_id) filters.appointment_id = appointment_id;
    if (customer_id) filters.customer_id = customer_id;
    if (search) filters.search = search;
    if (include_appointments) filters.include_appointments = include_appointments;

    const sales = await db.getSales(filters);
    res.json({ success: true, data: sales, count: sales.length });
  } catch (err) {
    console.error('Error fetching sales:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch sales.' });
  }
});

// GET /api/sales/:id
router.get('/:id', async (req, res) => {
  try {
    const sale = await db.getSaleById(req.params.id);
    if (!sale) {
      return res.status(404).json({ success: false, message: 'Sale not found.' });
    }
    res.json({ success: true, data: sale });
  } catch (err) {
    console.error('Error fetching sale:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch sale.' });
  }
});

// POST /api/sales — Create sale, auto-transition linked appointment to 'completed'
router.post('/', async (req, res) => {
  try {
    const {
      business_id, appointment_id, customer_id, customer_name, customer_phone,
      staff_id, staff_name,
      subtotal, item_discount_total, overall_discount, tax_amount, total_amount,
      payment_method, amount_tendered, change_amount,
      items, notes,
    } = req.body;

    if (!payment_method || !total_amount) {
      return res.status(400).json({
        success: false,
        message: 'payment_method and total_amount are required.',
      });
    }

    // Create the sale record
    const sale = await db.createSale({
      business_id: business_id || 1,
      appointment_id: appointment_id || null,
      customer_id: customer_id || null,
      customer_name: customer_name || '',
      customer_phone: customer_phone || '',
      staff_id: staff_id || null,
      staff_name: staff_name || '',
      subtotal: subtotal || 0,
      item_discount_total: item_discount_total || 0,
      overall_discount: overall_discount || 0,
      tax_amount: tax_amount || 0,
      total_amount,
      payment_method,
      amount_tendered: amount_tendered || 0,
      change_amount: change_amount || 0,
      items: items || [],
      notes: notes || '',
    });

    // Auto-transition: if linked to an appointment, update status to 'completed'
    if (appointment_id) {
      const appt = await db.getAppointmentById(appointment_id);
      if (appt && (appt.status === 'in_service' || appt.status === 'booked')) {
        await db.updateAppointmentStatus(appointment_id, 'completed');
        await db.updateAppointment(appointment_id, { total_amount });
      }
    }

    res.status(201).json({
      success: true,
      message: 'Sale recorded successfully!',
      data: sale,
    });
  } catch (err) {
    console.error('Error creating sale:', err);
    res.status(500).json({ success: false, message: 'Failed to create sale.' });
  }
});

module.exports = router;
