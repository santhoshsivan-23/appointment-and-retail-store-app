const express = require('express');
const net = require('net');
const router = express.Router();
const db = require('../config/db');

// Helper to build ESC/POS Test Printing buffer matching esc_pos.dart
function buildEscPosTestPrint({
  business_name,
  printer_name,
  ip_address,
  port,
  paper_size = 'mm80',
  auto_cut = true,
  open_cash_drawer = false,
  test_text = 'Test Printing',
}) {
  const esc = 0x1b;
  const gs = 0x1d;

  const init = Buffer.from([esc, 0x40]);
  const leftMarginZero = Buffer.from([gs, 0x4c, 0x00, 0x00]);
  const alignCenter = Buffer.from([esc, 0x61, 0x01]);
  const alignLeft = Buffer.from([esc, 0x61, 0x00]);
  const boldOn = Buffer.from([esc, 0x45, 0x01]);
  const boldOff = Buffer.from([esc, 0x45, 0x00]);
  const sizeDouble = Buffer.from([gs, 0x21, 0x11]);
  const sizeNormal = Buffer.from([gs, 0x21, 0x00]);
  const cut = Buffer.from([gs, 0x56, 0x41, 0x03]);
  const cashDrawer = Buffer.from([esc, 0x70, 0x00, 0x19, 0xfa]);

  const width = paper_size === 'mm58' ? 32 : 48;
  const sep = Buffer.from('-'.repeat(width) + '\n', 'utf8');

  const parts = [init, leftMarginZero, alignCenter];

  // Store / Business Name if present
  if (business_name && business_name.trim()) {
    parts.push(boldOn, Buffer.from(`${business_name.trim()}\n`, 'utf8'), boldOff);
  }

  parts.push(sep);

  // Prominent "Test Printing" header (double size, bold, centered)
  const headerText = test_text || 'Test Printing';
  parts.push(
    alignCenter,
    sizeDouble,
    boldOn,
    Buffer.from(`${headerText}\n`, 'utf8'),
    boldOff,
    sizeNormal
  );

  parts.push(sep);

  // Date & Time
  const now = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  const formattedDate = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}`;
  const formattedTime = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;

  parts.push(alignLeft);
  const dateStr = `Date: ${formattedDate}`;
  const timeStr = `Time: ${formattedTime}`;
  const spaceCount = Math.max(1, width - dateStr.length - timeStr.length);
  parts.push(Buffer.from(`${dateStr}${' '.repeat(spaceCount)}${timeStr}\n`, 'utf8'));
  parts.push(sep);

  // Diagnostic Info
  parts.push(Buffer.from(`Printer : ${printer_name || 'Main Counter LAN Printer'}\n`, 'utf8'));
  parts.push(Buffer.from(`IP      : ${ip_address}:${port}\n`, 'utf8'));
  parts.push(
    Buffer.from(`Roll    : ${paper_size === 'mm58' ? '58mm (32 Col)' : '80mm (48 Col)'}\n`, 'utf8')
  );
  parts.push(Buffer.from(`Status  : Printer Working Successfully\n`, 'utf8'));
  parts.push(sep);

  // Footer
  parts.push(alignCenter);
  parts.push(boldOn);
  parts.push(Buffer.from(`*** TEST PRINT COMPLETED ***\n`, 'utf8'));
  parts.push(boldOff);
  parts.push(Buffer.from(`Powered by IQ POS\n`, 'utf8'));

  // Feed paper so cut line is past the print head
  parts.push(Buffer.from('\n\n\n\n\n', 'utf8'));

  // Auto cut
  if (auto_cut !== false) {
    parts.push(cut);
  }

  // Cash drawer
  if (open_cash_drawer) {
    parts.push(cashDrawer);
  }

  return Buffer.concat(parts);
}

// POST /api/settings/test-print
router.post('/test-print', async (req, res) => {
  const {
    ip_address,
    port,
    printer_name,
    business_name,
    paper_size,
    auto_cut,
    open_cash_drawer,
    test_text,
  } = req.body || {};

  if (!ip_address) {
    return res.status(400).json({
      success: false,
      message: 'LAN printer IP address is required.',
    });
  }

  const targetPort = parseInt(port, 10) || 9100;
  const socket = new net.Socket();
  let finished = false;

  const escBuffer = buildEscPosTestPrint({
    business_name,
    printer_name,
    ip_address,
    port: targetPort,
    paper_size,
    auto_cut,
    open_cash_drawer,
    test_text: test_text || 'Test Printing',
  });

  const timeout = setTimeout(() => {
    if (!finished) {
      finished = true;
      socket.destroy();
      return res.json({
        success: false,
        message: `Connection timed out. LAN printer at ${ip_address}:${targetPort} did not answer within 5 seconds.`,
      });
    }
  }, 5000);

  socket.once('error', (err) => {
    if (!finished) {
      finished = true;
      clearTimeout(timeout);
      return res.json({
        success: false,
        message: `LAN printer connection failed: ${err.message}`,
      });
    }
  });

  socket.connect(targetPort, ip_address, () => {
    if (!finished) {
      finished = true;
      clearTimeout(timeout);
      socket.write(escBuffer, () => {
        socket.end();
      });
      return res.json({
        success: true,
        message: `Successfully printed "Test Printing" on LAN printer at ${ip_address}:${targetPort}!`,
      });
    }
  });
});

// Helper to build ESC/POS Customer Order Receipt matching standard thermal receipt
function buildEscPosOrderReceipt(printerSettings, rawTx, options = {}) {
  const esc = 0x1b;
  const gs = 0x1d;

  const init = Buffer.from([esc, 0x40]);
  const leftMarginZero = Buffer.from([gs, 0x4c, 0x00, 0x00]);
  const alignCenter = Buffer.from([esc, 0x61, 0x01]);
  const alignLeft = Buffer.from([esc, 0x61, 0x00]);
  const boldOn = Buffer.from([esc, 0x45, 0x01]);
  const boldOff = Buffer.from([esc, 0x45, 0x00]);
  const cut = Buffer.from([gs, 0x56, 0x41, 0x03]);
  const cashDrawer = Buffer.from([esc, 0x70, 0x00, 0x19, 0xfa]);

  const paperSize = printerSettings?.paper_size || 'mm80';
  const width = paperSize === 'mm58' ? 32 : 48;
  const sep = Buffer.from('-'.repeat(width) + '\n', 'utf8');
  const dsep = Buffer.from('='.repeat(width) + '\n', 'utf8');

  const padLine = (left, right, w = width) => {
    const l = String(left || '');
    const r = String(right || '');
    const space = Math.max(1, w - l.length - r.length);
    return `${l}${' '.repeat(space)}${r}\n`;
  };

  const clip = (str, len) => {
    const s = String(str || '');
    return s.length <= len ? s : s.substring(0, len);
  };

  const fmtMoney = (val) => {
    const n = Number(val) || 0;
    return `$${n.toFixed(2)}`;
  };

  const parts = [init, leftMarginZero];

  // Detect whether this transaction is an appointment or a cart sale
  const isAppointment = Boolean(
    options.type === 'appointment' ||
    rawTx.appointment_date ||
    (rawTx.services && Array.isArray(rawTx.services)) ||
    (rawTx.appointment_id && !rawTx.items)
  );

  const isReprint = Boolean(options.is_reprint !== undefined ? options.is_reprint : rawTx.is_reprint);

  // 1. Store Header (Centered)
  parts.push(alignCenter);
  const storeName = printerSettings?.business_name || 'IQ RESTAURANT & POS';
  parts.push(boldOn, Buffer.from(`${storeName}\n`, 'utf8'), boldOff);

  const addrFields = [
    printerSettings?.addr_line1,
    printerSettings?.addr_line2,
    printerSettings?.addr_line3,
    printerSettings?.addr_line4,
    printerSettings?.phone_number ? `Tel: ${printerSettings.phone_number}` : null,
  ].filter(Boolean);

  for (const line of addrFields) {
    parts.push(Buffer.from(`${line}\n`, 'utf8'));
  }

  if (printerSettings?.header_note) {
    parts.push(boldOn, Buffer.from(`${printerSettings.header_note}\n`, 'utf8'), boldOff);
  }

  // Reprint / Duplicate banner if reprinting
  if (isReprint) {
    parts.push(sep);
    parts.push(boldOn, Buffer.from('*** REPRINT RECEIPT ***\n', 'utf8'), boldOff);
    if (rawTx.refund_status === 'full') {
      parts.push(boldOn, Buffer.from('*** STATUS: FULLY REFUNDED ***\n', 'utf8'), boldOff);
    } else if (rawTx.refund_status === 'partial') {
      parts.push(boldOn, Buffer.from('*** STATUS: PARTIALLY REFUNDED ***\n', 'utf8'), boldOff);
    }
  }

  parts.push(sep);

  // 2. Receipt Meta (Date, Time, Receipt #, Staff, Customer)
  parts.push(alignLeft);

  const pad = (n) => String(n).padStart(2, '0');
  let dateStr = '';
  let timeStr = '';

  if (isAppointment && rawTx.appointment_date) {
    dateStr = String(rawTx.appointment_date);
    timeStr = rawTx.start_time
      ? (rawTx.end_time ? `${rawTx.start_time} - ${rawTx.end_time}` : rawTx.start_time)
      : '';
  } else {
    const saleDate = rawTx.created_at ? new Date(rawTx.created_at) : new Date();
    dateStr = `${pad(saleDate.getDate())}/${pad(saleDate.getMonth() + 1)}/${saleDate.getFullYear()}`;
    timeStr = `${pad(saleDate.getHours())}:${pad(saleDate.getMinutes())}:${pad(saleDate.getSeconds())}`;
  }

  parts.push(Buffer.from(padLine(`Date: ${dateStr}`, timeStr ? `Time: ${timeStr}` : ''), 'utf8'));

  const receiptNo =
    rawTx.receipt_number ||
    (isAppointment
      ? `#APT-${String(rawTx.id).padStart(4, '0')}`
      : `#REC-${String(rawTx.id).padStart(4, '0')}`);
  const payMethod = (rawTx.payment_method || 'CASH').toUpperCase();
  parts.push(Buffer.from(padLine(`Receipt: ${receiptNo}`, `Pay: ${payMethod}`), 'utf8'));

  if (rawTx.staff_name) {
    const staffRole = isAppointment ? 'Attendant' : 'Cashier';
    parts.push(Buffer.from(`${staffRole}: ${rawTx.staff_name}\n`, 'utf8'));
  }
  if (rawTx.customer_name && rawTx.customer_name !== 'Walk-in') {
    parts.push(
      Buffer.from(
        `Customer: ${rawTx.customer_name}${rawTx.customer_phone ? ` (${rawTx.customer_phone})` : ''}\n`,
        'utf8'
      )
    );
  }

  parts.push(sep);

  // 3. Item Column Headers (Left Aligned)
  parts.push(boldOn);
  const priceW = 10;
  const qtyW = 5;
  const itemW = width - qtyW - priceW - 1;
  const headerRow = `${'Qty'.padEnd(qtyW)}${'Item'.padEnd(itemW)} ${'Price'.padStart(priceW)}\n`;
  parts.push(Buffer.from(headerRow, 'utf8'), boldOff);
  parts.push(sep);

  // 4. Items List with Refunded Items Directly Below Original Product
  let rawItems = [];
  if (Array.isArray(rawTx.items) && rawTx.items.length > 0) {
    rawItems = rawTx.items;
  } else if (Array.isArray(rawTx.services) && rawTx.services.length > 0) {
    rawItems = rawTx.services.map((s) => ({
      product_id: s.id || s.product_id,
      product_name: s.name || s.product_name || 'Service',
      unit_price: Number(s.price !== undefined ? s.price : s.unit_price) || 0,
      quantity: Number(s.quantity) || 1,
      discount: Number(s.discount) || 0,
      line_total:
        Number(s.line_total) ||
        ((Number(s.price !== undefined ? s.price : s.unit_price) || 0) * (Number(s.quantity) || 1)),
    }));
  }

  const allRefunds = Array.isArray(rawTx.refunds) ? rawTx.refunds : [];

  for (const it of rawItems) {
    const qty = Number(it.quantity) || 1;
    const unitPrice = Number(it.unit_price) || 0;
    const lineTotal = Number(it.line_total) || unitPrice * qty;
    const pName = it.product_name || it.name || 'Item';

    const qtyStr = `${qty}x`.padEnd(qtyW);
    const priceStr = fmtMoney(lineTotal).padStart(priceW);
    const nameStr = clip(pName, itemW).padEnd(itemW);
    parts.push(Buffer.from(`${qtyStr}${nameStr} ${priceStr}\n`, 'utf8'));

    // Unit price or discount detail row if applicable
    if (qty > 1 || Number(it.discount) > 0) {
      let subDetail = `  @ ${fmtMoney(unitPrice)}`;
      if (Number(it.discount) > 0) {
        subDetail += ` (Disc: -${fmtMoney(it.discount)})`;
      }
      parts.push(Buffer.from(`${clip(subDetail, width)}\n`, 'utf8'));
    }

    // Match refunds corresponding to this original item
    const itKey = String(it.product_id || it.id || pName).toLowerCase();
    const matchedRefunds = [];

    for (const rf of allRefunds) {
      if (!Array.isArray(rf.items)) continue;
      for (const rIt of rf.items) {
        const rKey = String(rIt.product_id || rIt.id || rIt.product_name || '').toLowerCase();
        const nameMatch =
          pName &&
          rIt.product_name &&
          pName.trim().toLowerCase() === rIt.product_name.trim().toLowerCase();
        if ((itKey && rKey && itKey === rKey) || nameMatch) {
          const rQty = Number(rIt.quantity) || 1;
          const rAmt =
            Number(rIt.refund_amount) ||
            ((Number(rIt.unit_price || unitPrice) || 0) * rQty);
          matchedRefunds.push({
            refund_no: rf.refund_receipt_number,
            refund_date: rf.created_at,
            quantity: rQty,
            refund_amount: rAmt,
            gst_reversed: Number(rIt.gst_reversed) || 0,
            reason: rf.reason,
            method: rf.refund_method,
          });
        }
      }
    }

    // If item was refunded, display just refunded qty below original product
    if (matchedRefunds.length > 0) {
      const itemRefundedQty = matchedRefunds.reduce((sum, r) => sum + r.quantity, 0);
      parts.push(boldOn);
      parts.push(Buffer.from(`  Refunded: ${itemRefundedQty}x\n`, 'utf8'));
      parts.push(boldOff);
    }
  }

  parts.push(sep);

  // 5. Financial Summary
  const totalAmount = Number(rawTx.total_amount) || 0;
  const totalRefunded =
    Number(rawTx.refunded_amount) ||
    allRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);

  const totalGstRefunded =
    rawTx.gst_reversed_total !== undefined
      ? Number(rawTx.gst_reversed_total)
      : allRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);

  const netTax =
    rawTx.net_tax_amount !== undefined
      ? Number(rawTx.net_tax_amount)
      : Math.max(0, Math.round(((Number(rawTx.tax_amount) || 0) - totalGstRefunded) * 100) / 100);

  const totalSubtotalRefunded =
    rawTx.subtotal_refunded_total !== undefined
      ? Number(rawTx.subtotal_refunded_total)
      : allRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);

  const netSubtotal =
    rawTx.net_subtotal !== undefined
      ? Number(rawTx.net_subtotal)
      : Math.max(0, Math.round(((Number(rawTx.subtotal) || 0) - totalSubtotalRefunded) * 100) / 100);

  if (rawTx.subtotal !== undefined) {
    const displaySubtotal = totalRefunded > 0 ? netSubtotal : Number(rawTx.subtotal);
    parts.push(Buffer.from(padLine('Subtotal', fmtMoney(displaySubtotal)), 'utf8'));
  }
  if (Number(rawTx.item_discount_total) > 0) {
    parts.push(Buffer.from(padLine('Item Discounts', `-${fmtMoney(rawTx.item_discount_total)}`), 'utf8'));
  }
  if (Number(rawTx.overall_discount) > 0) {
    parts.push(Buffer.from(padLine('Overall Discount', `-${fmtMoney(rawTx.overall_discount)}`), 'utf8'));
  }
  if (Number(rawTx.tax_amount) > 0 || totalGstRefunded > 0) {
    const displayTax = totalGstRefunded > 0 ? netTax : Number(rawTx.tax_amount);
    parts.push(Buffer.from(padLine('Tax (8%)', fmtMoney(displayTax)), 'utf8'));
  }

  parts.push(dsep);

  if (totalRefunded > 0) {
    parts.push(Buffer.from(padLine('Original Total', fmtMoney(totalAmount)), 'utf8'));
    parts.push(boldOn);
    parts.push(Buffer.from(padLine('TOTAL REFUNDED', `-${fmtMoney(totalRefunded)}`), 'utf8'));
    parts.push(boldOff);
    parts.push(sep);
    const netRetained = Math.max(0, totalAmount - totalRefunded);
    parts.push(boldOn);
    parts.push(Buffer.from(padLine('NET AMOUNT PAID', fmtMoney(netRetained)), 'utf8'));
    parts.push(boldOff);
  } else {
    parts.push(boldOn);
    parts.push(Buffer.from(padLine('GRAND TOTAL', fmtMoney(totalAmount)), 'utf8'));
    parts.push(boldOff);
  }

  // Cash Tendered & Change (only relevant if not full refund or on original sale)
  if (String(rawTx.payment_method).toLowerCase() === 'cash') {
    if (rawTx.amount_tendered !== undefined && Number(rawTx.amount_tendered) > 0) {
      parts.push(sep);
      parts.push(Buffer.from(padLine('Amount Tendered', fmtMoney(rawTx.amount_tendered)), 'utf8'));
      parts.push(Buffer.from(padLine('Change Due', fmtMoney(rawTx.change_amount)), 'utf8'));
    }
  }

  parts.push(sep);

  // 6. Footer (Centered)
  parts.push(alignCenter);
  const footerNote =
    printerSettings?.footer_note || 'Thank you for your visit! Please come again.';
  parts.push(Buffer.from(`${footerNote}\n`, 'utf8'));
  parts.push(Buffer.from('Powered by IQ POS\n', 'utf8'));

  // 7. Feed 4 lines
  parts.push(Buffer.from('\n\n\n\n', 'utf8'));

  // 8. Auto cut
  if (printerSettings?.auto_cut !== false) {
    parts.push(cut);
  }

  // 9. Cash drawer kick (skip drawer kick on reprint)
  if (
    !isReprint &&
    printerSettings?.open_cash_drawer &&
    String(rawTx.payment_method).toLowerCase() === 'cash'
  ) {
    parts.push(cashDrawer);
  }

  return Buffer.concat(parts);
}

// POST /api/settings/print-receipt
router.post('/print-receipt', async (req, res) => {
  try {
    let { printer_settings, sale, appointment, is_reprint, type } = req.body || {};

    const transaction = sale || appointment;
    if (!transaction) {
      return res.status(400).json({
        success: false,
        message: 'Transaction details (sale or appointment) are required to print a receipt.',
      });
    }

    // Determine type
    const txType = type || (appointment ? 'appointment' : (transaction.appointment_id ? 'appointment' : 'sale'));

    // If refunds are not populated on transaction, fetch from DB
    if (!transaction.refunds || transaction.refunds.length === 0) {
      try {
        let dbRefunds = [];
        if (txType === 'appointment' || appointment) {
          dbRefunds = await db.getAppointmentRefunds(transaction.id);
        } else {
          dbRefunds = await db.getSaleRefunds(transaction.id);
        }
        if (dbRefunds && dbRefunds.length > 0) {
          transaction.refunds = dbRefunds;
          const totalRef = dbRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
          const totalGstRef = dbRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
          const totalSubtotalRef = dbRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
          transaction.refunded_amount = Number(transaction.refunded_amount) || totalRef;
          transaction.gst_reversed_total = totalGstRef;
          transaction.net_tax_amount = Math.max(0, Math.round(((Number(transaction.tax_amount) || 0) - totalGstRef) * 100) / 100);
          transaction.subtotal_refunded_total = totalSubtotalRef;
          transaction.net_subtotal = Math.max(0, Math.round(((Number(transaction.subtotal || transaction.total_amount) || 0) - totalSubtotalRef) * 100) / 100);
          transaction.refund_status =
            transaction.refund_status ||
            (totalRef >= Number(transaction.total_amount) ? 'full' : 'partial');
        }
      } catch (e) {
        console.warn('Could not auto-fetch refunds for receipt print:', e.message);
      }
    }

    // If printer settings wasn't supplied directly in payload, load from database
    if (!printer_settings) {
      const dbSettings = await db.getSettings(transaction.business_id || 1);
      printer_settings = dbSettings?.printer_settings;
    }

    if (!printer_settings) {
      return res.status(400).json({
        success: false,
        message: 'No LAN printer settings found. Please configure a printer first.',
      });
    }

    if (printer_settings.is_enabled === false) {
      return res.json({
        success: false,
        message: 'Printer is toggled off in settings. Print skipped.',
      });
    }

    if (printer_settings.order_receipt_enabled === false) {
      return res.json({
        success: false,
        message: 'Customer Order Receipt printing is disabled in settings. Print skipped.',
      });
    }

    const ip_address = printer_settings.ip_address?.trim();
    if (!ip_address) {
      return res.status(400).json({
        success: false,
        message: 'LAN printer IP address is not configured.',
      });
    }

    const targetPort = parseInt(printer_settings.port, 10) || 9100;
    const escBuffer = buildEscPosOrderReceipt(printer_settings, transaction, {
      is_reprint: is_reprint !== undefined ? is_reprint : true,
      type: txType,
    });

    const socket = new net.Socket();
    let finished = false;

    const timeout = setTimeout(() => {
      if (!finished) {
        finished = true;
        socket.destroy();
        return res.json({
          success: false,
          message: `Connection timed out. LAN printer at ${ip_address}:${targetPort} did not answer within 5 seconds.`,
        });
      }
    }, 5000);

    socket.once('error', (err) => {
      if (!finished) {
        finished = true;
        clearTimeout(timeout);
        return res.json({
          success: false,
          message: `LAN printer error: ${err.message}`,
        });
      }
    });

    socket.connect(targetPort, ip_address, () => {
      if (!finished) {
        finished = true;
        clearTimeout(timeout);
        socket.write(escBuffer, () => {
          socket.end();
        });
        const docLabel = txType === 'appointment' ? 'Appointment Receipt' : 'Order Receipt';
        const reprintTag = is_reprint ? ' (Reprint)' : '';
        return res.json({
          success: true,
          message: `${docLabel}${reprintTag} successfully sent to LAN printer at ${ip_address}:${targetPort}!`,
        });
      }
    });
  } catch (err) {
    console.error('Error printing receipt:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to dispatch receipt to printer.',
      error: err.message,
    });
  }
});
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

router.buildEscPosOrderReceipt = buildEscPosOrderReceipt;
module.exports = router;
