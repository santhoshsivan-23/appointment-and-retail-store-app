const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/sales?start_date=...&end_date=...&payment_method=...&page=...&limit=...
router.get('/', async (req, res) => {
  try {
    const {
      appointment_id,
      customer_id,
      search,
      include_appointments,
      start_date,
      end_date,
      payment_method,
      page,
      limit,
    } = req.query;

    const filters = {};
    if (appointment_id) filters.appointment_id = appointment_id;
    if (customer_id) filters.customer_id = customer_id;
    if (search) filters.search = search;
    if (include_appointments) filters.include_appointments = include_appointments;
    if (start_date) filters.start_date = start_date;
    if (end_date) filters.end_date = end_date;
    if (payment_method) filters.payment_method = payment_method;
    if (page) filters.page = page;
    if (limit) filters.limit = limit;

    const sales = await db.getSales(filters);

    if (sales && sales.total !== undefined) {
      return res.json({
        success: true,
        data: sales.data,
        total: sales.total,
        page: sales.page,
        limit: sales.limit,
        totalPages: sales.totalPages,
        count: sales.data.length,
      });
    }

    res.json({ success: true, data: sales, count: sales.length });
  } catch (err) {
    console.error('Error fetching sales:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch sales.' });
  }
});

// GET /api/sales/summary?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&search=...&payment_method=...
router.get('/summary', async (req, res) => {
  try {
    const { start_date, end_date, search, payment_method, include_appointments } = req.query;
    const summary = await db.getSaleSummary({
      startDate: start_date || null,
      endDate: end_date || null,
      search: search || null,
      paymentMethod: payment_method || null,
      include_appointments,
    });
    res.json({ success: true, data: summary });
  } catch (err) {
    console.error('Error fetching sale summary:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch sale summary.' });
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

// GET /api/sales/:id/refunds
router.get('/:id/refunds', async (req, res) => {
  try {
    const refunds = await db.getSaleRefunds(req.params.id);
    res.json({ success: true, data: refunds, count: refunds.length });
  } catch (err) {
    console.error('Error fetching sale refunds:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch refunds.' });
  }
});

// POST /api/sales/:id/refund
router.post('/:id/refund', async (req, res) => {
  try {
    const { items, reason, notes, refund_method } = req.body;
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'items array is required with at least one item to refund.',
      });
    }

    const result = await db.createSaleRefund({
      sale_id: req.params.id,
      items,
      reason: reason || '',
      notes: notes || '',
      refund_method: refund_method || 'cash',
    });

    res.status(201).json({
      success: true,
      message: 'Refund processed successfully!',
      data: result.refund,
      sale: result.sale,
    });
  } catch (err) {
    console.error('Error processing sale refund:', err);
    res.status(400).json({ success: false, message: err.message || 'Failed to process refund.' });
  }
});

module.exports = router;

