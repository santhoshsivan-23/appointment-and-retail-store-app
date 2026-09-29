const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /api/appointments?date=YYYY-MM-DD&staff_id=X
router.get('/', async (req, res) => {
  try {
    const { date, staff_id } = req.query;
    const appointments = await db.getAppointments(date || null, staff_id || null);
    res.json({ success: true, data: appointments, count: appointments.length });
  } catch (err) {
    console.error('Error fetching appointments:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch appointments.' });
  }
});

// GET /api/appointments/stats/overview?date=YYYY-MM-DD
// GET /api/appointments/overview?date=YYYY-MM-DD
const handleOverviewStats = async (req, res) => {
  try {
    const { date } = req.query;
    const stats = await db.getAppointmentStats(date || null);
    res.json({ success: true, date: date || null, data: stats });
  } catch (err) {
    console.error('Error fetching appointment stats:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch appointment stats.' });
  }
};

router.get('/stats/overview', handleOverviewStats);
router.get('/overview', handleOverviewStats);

// GET /api/appointments/:id
router.get('/:id', async (req, res) => {
  try {
    const appointment = await db.getAppointmentById(req.params.id);
    if (!appointment) {
      return res.status(404).json({ success: false, message: 'Appointment not found.' });
    }
    res.json({ success: true, data: appointment });
  } catch (err) {
    console.error('Error fetching appointment:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch appointment.' });
  }
});

// POST /api/appointments
router.post('/', async (req, res) => {
  try {
    const { staff_id, customer_id, customer_name, customer_phone, appointment_date, start_time, end_time, services, notes, total_amount } = req.body;

    if (!staff_id || !appointment_date || !start_time || !end_time) {
      return res.status(400).json({
        success: false,
        message: 'staff_id, appointment_date, start_time, and end_time are required.',
      });
    }

    const newAppointment = await db.createAppointment({
      business_id: req.body.business_id || 1,
      staff_id,
      customer_id: customer_id || null,
      customer_name: customer_name || '',
      customer_phone: customer_phone || '',
      appointment_date,
      start_time,
      end_time,
      status: 'booked',
      total_amount: total_amount || 0,
      services: services || [],
      notes: notes || '',
    });

    res.status(201).json({
      success: true,
      message: 'Appointment created successfully!',
      data: newAppointment,
    });
  } catch (err) {
    console.error('Error creating appointment:', err);
    res.status(500).json({ success: false, message: 'Failed to create appointment.' });
  }
});

// PUT /api/appointments/:id/status
router.put('/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['booked', 'in_service', 'completed', 'no_show', 'cancelled'];

    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`,
      });
    }

    const updated = await db.updateAppointmentStatus(req.params.id, status);
    if (!updated) {
      return res.status(404).json({ success: false, message: 'Appointment not found.' });
    }

    res.json({
      success: true,
      message: `Appointment status updated to "${status}".`,
      data: updated,
    });
  } catch (err) {
    console.error('Error updating appointment status:', err);
    res.status(500).json({ success: false, message: 'Failed to update appointment status.' });
  }
});

// PUT /api/appointments/:id
router.put('/:id', async (req, res) => {
  try {
    const updated = await db.updateAppointment(req.params.id, req.body);
    if (!updated) {
      return res.status(404).json({ success: false, message: 'Appointment not found.' });
    }

    res.json({
      success: true,
      message: 'Appointment updated successfully!',
      data: updated,
    });
  } catch (err) {
    console.error('Error updating appointment:', err);
    res.status(500).json({ success: false, message: 'Failed to update appointment.' });
  }
});

// DELETE /api/appointments/:id
router.delete('/:id', async (req, res) => {
  try {
    const deleted = await db.deleteAppointment(req.params.id);
    if (!deleted) {
      return res.status(404).json({ success: false, message: 'Appointment not found.' });
    }

    res.json({ success: true, message: 'Appointment deleted.' });
  } catch (err) {
    console.error('Error deleting appointment:', err);
    res.status(500).json({ success: false, message: 'Failed to delete appointment.' });
  }
});

// POST /api/appointments/check-conflict
router.post('/check-conflict', async (req, res) => {
  try {
    const { staff_id, appointment_date, start_time, end_time, exclude_id } = req.body;

    if (!staff_id || !appointment_date || !start_time || !end_time) {
      return res.status(400).json({
        success: false,
        message: 'staff_id, appointment_date, start_time, and end_time are required.',
      });
    }

    const result = await db.checkAppointmentConflict({
      staff_id,
      appointment_date,
      start_time,
      end_time,
      exclude_id: exclude_id || null,
    });

    res.json({ success: true, ...result });
  } catch (err) {
    console.error('Error checking conflict:', err);
    res.status(500).json({ success: false, message: 'Failed to check conflict.' });
  }
});

module.exports = router;
