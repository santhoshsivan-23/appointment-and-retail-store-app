import type { LanPrinterSettings } from '../api/settingsApi';

/* ── Byte Constants for ESC/POS ───────────────────────────── */
const ESC = 0x1b;
const GS = 0x1d;

const CMD_INIT = [ESC, 0x40];
const CMD_LEFT_MARGIN_ZERO = [GS, 0x4c, 0x00, 0x00];
const CMD_ALIGN_CENTER = [ESC, 0x61, 0x01];
const CMD_ALIGN_LEFT = [ESC, 0x61, 0x00];
const CMD_BOLD_ON = [ESC, 0x45, 0x01];
const CMD_BOLD_OFF = [ESC, 0x45, 0x00];
const CMD_SIZE_DOUBLE = [GS, 0x21, 0x11];
const CMD_SIZE_NORMAL = [GS, 0x21, 0x00];
const CMD_CUT = [GS, 0x56, 0x41, 0x03];
const CMD_CASH_DRAWER = [ESC, 0x70, 0x00, 0x19, 0xfa];

const encoder = new TextEncoder();
const textBytes = (str: string): number[] => Array.from(encoder.encode(str));

const fmtMoney = (val: number | string | null | undefined): string => {
  const n = Number(val) || 0;
  return `$${n.toFixed(2)}`;
};

const clip = (str: string, len: number): string => {
  const s = String(str || '');
  return s.length <= len ? s : s.substring(0, len);
};

const padLine = (left: string, right: string, width: number): string => {
  const l = String(left || '');
  const r = String(right || '');
  const space = Math.max(1, width - l.length - r.length);
  return `${l}${' '.repeat(space)}${r}\n`;
};

/**
 * Builds ESC/POS binary data for "Test Printing".
 */
export function buildEscPosTestPrint(printerSettings?: LanPrinterSettings | null): Uint8Array {
  const paperSize = printerSettings?.paper_size || 'mm80';
  const width = paperSize === 'mm58' ? 32 : 48;
  const storeName = printerSettings?.business_name || 'IQ Store';
  const printerName = printerSettings?.printer_name || 'Main Counter LAN Printer';
  const ipAddress = printerSettings?.ip_address || '192.168.1.51';
  const port = printerSettings?.port || 9100;
  const autoCut = printerSettings?.auto_cut !== false;
  const openCashDrawer = Boolean(printerSettings?.open_cash_drawer);

  const bytes: number[] = [];

  // Init & margins
  bytes.push(...CMD_INIT, ...CMD_LEFT_MARGIN_ZERO);

  // Store header (centered)
  bytes.push(...CMD_ALIGN_CENTER);
  if (storeName.trim()) {
    bytes.push(...CMD_BOLD_ON, ...textBytes(`${storeName.trim()}\n`), ...CMD_BOLD_OFF);
  }

  const sep = textBytes('-'.repeat(width) + '\n');
  bytes.push(...sep);

  // Prominent "Test Printing" header (double size, bold, centered)
  bytes.push(
    ...CMD_ALIGN_CENTER,
    ...CMD_SIZE_DOUBLE,
    ...CMD_BOLD_ON,
    ...textBytes('Test Printing\n'),
    ...CMD_BOLD_OFF,
    ...CMD_SIZE_NORMAL
  );

  bytes.push(...sep);

  // Date & Time
  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  const formattedDate = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}`;
  const formattedTime = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;

  bytes.push(...CMD_ALIGN_LEFT);
  const dateStr = `Date: ${formattedDate}`;
  const timeStr = `Time: ${formattedTime}`;
  const spaceCount = Math.max(1, width - dateStr.length - timeStr.length);
  bytes.push(...textBytes(`${dateStr}${' '.repeat(spaceCount)}${timeStr}\n`));
  bytes.push(...sep);

  // Diagnostic Info
  bytes.push(...textBytes(`Printer : ${printerName}\n`));
  bytes.push(...textBytes(`IP      : ${ipAddress}:${port}\n`));
  bytes.push(...textBytes(`Roll    : ${paperSize === 'mm58' ? '58mm (32 Col)' : '80mm (48 Col)'}\n`));
  bytes.push(...textBytes(`Status  : Printer Working Successfully\n`));
  bytes.push(...sep);

  // Footer
  bytes.push(...CMD_ALIGN_CENTER, ...CMD_BOLD_ON, ...textBytes('*** TEST PRINT COMPLETED ***\n'), ...CMD_BOLD_OFF);
  bytes.push(...textBytes('Powered by IQ POS (Direct LAN Print)\n'));

  // Feed lines
  bytes.push(...textBytes('\n\n\n\n\n'));

  // Auto cut
  if (autoCut) {
    bytes.push(...CMD_CUT);
  }

  // Cash drawer
  if (openCashDrawer) {
    bytes.push(...CMD_CASH_DRAWER);
  }

  return new Uint8Array(bytes);
}

/**
 * Builds ESC/POS binary data for Customer Order Receipts and Appointment Receipts.
 */
export function buildEscPosOrderReceipt(
  printerSettings: LanPrinterSettings | null | undefined,
  rawTx: any,
  options: { type?: 'sale' | 'appointment'; isReprint?: boolean } = {}
): Uint8Array {
  const paperSize = printerSettings?.paper_size || 'mm80';
  const width = paperSize === 'mm58' ? 32 : 48;
  const sep = textBytes('-'.repeat(width) + '\n');
  const dsep = textBytes('='.repeat(width) + '\n');

  const isAppointment = Boolean(
    options.type === 'appointment' ||
    rawTx.appointment_date ||
    (rawTx.services && Array.isArray(rawTx.services))
  );
  const isReprint = Boolean(options.isReprint !== undefined ? options.isReprint : rawTx.is_reprint);

  const bytes: number[] = [];

  // Init & Margin
  bytes.push(...CMD_INIT, ...CMD_LEFT_MARGIN_ZERO);

  // 1. Store Header (Centered)
  bytes.push(...CMD_ALIGN_CENTER);
  const storeName = printerSettings?.business_name || 'IQ RESTAURANT & POS';
  bytes.push(...CMD_BOLD_ON, ...textBytes(`${storeName}\n`), ...CMD_BOLD_OFF);

  const addrFields = [
    printerSettings?.addr_line1,
    printerSettings?.addr_line2,
    printerSettings?.addr_line3,
    printerSettings?.addr_line4,
    printerSettings?.phone_number ? `Tel: ${printerSettings.phone_number}` : null,
  ].filter(Boolean) as string[];

  for (const line of addrFields) {
    bytes.push(...textBytes(`${line}\n`));
  }

  if (printerSettings?.header_note) {
    bytes.push(...CMD_BOLD_ON, ...textBytes(`${printerSettings.header_note}\n`), ...CMD_BOLD_OFF);
  }

  // Reprint / Duplicate banner if reprinting
  if (isReprint) {
    bytes.push(...sep);
    bytes.push(...CMD_BOLD_ON, ...textBytes('*** REPRINT RECEIPT ***\n'), ...CMD_BOLD_OFF);
    if (rawTx.refund_status === 'full') {
      bytes.push(...CMD_BOLD_ON, ...textBytes('*** STATUS: FULLY REFUNDED ***\n'), ...CMD_BOLD_OFF);
    } else if (rawTx.refund_status === 'partial') {
      bytes.push(...CMD_BOLD_ON, ...textBytes('*** STATUS: PARTIALLY REFUNDED ***\n'), ...CMD_BOLD_OFF);
    }
  }

  bytes.push(...sep);

  // 2. Receipt Meta (Left aligned)
  bytes.push(...CMD_ALIGN_LEFT);
  const pad = (n: number) => String(n).padStart(2, '0');
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

  bytes.push(...textBytes(padLine(`Date: ${dateStr}`, timeStr ? `Time: ${timeStr}` : '', width)));

  const receiptNo =
    rawTx.receipt_number ||
    (isAppointment
      ? `#APT-${String(rawTx.id).padStart(4, '0')}`
      : `#REC-${String(rawTx.id).padStart(4, '0')}`);
  const payMethod = (rawTx.payment_method || 'CASH').toUpperCase();
  bytes.push(...textBytes(padLine(`Receipt: ${receiptNo}`, `Pay: ${payMethod}`, width)));

  if (rawTx.staff_name) {
    const staffRole = isAppointment ? 'Attendant' : 'Cashier';
    bytes.push(...textBytes(`${staffRole}: ${rawTx.staff_name}\n`));
  }
  if (rawTx.customer_name && rawTx.customer_name !== 'Walk-in') {
    bytes.push(
      ...textBytes(
        `Customer: ${rawTx.customer_name}${rawTx.customer_phone ? ` (${rawTx.customer_phone})` : ''}\n`
      )
    );
  }

  bytes.push(...sep);

  // 3. Item Column Headers
  bytes.push(...CMD_BOLD_ON);
  const priceW = 10;
  const qtyW = 5;
  const itemW = width - qtyW - priceW - 1;
  const headerRow = `${'Qty'.padEnd(qtyW)}${'Item'.padEnd(itemW)} ${'Price'.padStart(priceW)}\n`;
  bytes.push(...textBytes(headerRow), ...CMD_BOLD_OFF);
  bytes.push(...sep);

  // 4. Items List
  let rawItems: any[] = [];
  if (Array.isArray(rawTx.items) && rawTx.items.length > 0) {
    rawItems = rawTx.items;
  } else if (Array.isArray(rawTx.services) && rawTx.services.length > 0) {
    rawItems = rawTx.services.map((s: any) => ({
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

  const allRefunds: any[] = Array.isArray(rawTx.refunds) ? rawTx.refunds : [];

  for (const it of rawItems) {
    const qty = Number(it.quantity) || 1;
    const unitPrice = Number(it.unit_price) || 0;
    const lineTotal = Number(it.line_total) || unitPrice * qty;
    const pName = it.product_name || it.name || 'Item';

    const qtyStr = `${qty}x`.padEnd(qtyW);
    const priceStr = fmtMoney(lineTotal).padStart(priceW);
    const nameStr = clip(pName, itemW).padEnd(itemW);
    bytes.push(...textBytes(`${qtyStr}${nameStr} ${priceStr}\n`));

    // Unit price or discount detail row if applicable
    if (qty > 1 || Number(it.discount) > 0) {
      let subDetail = `  @ ${fmtMoney(unitPrice)}`;
      if (Number(it.discount) > 0) {
        subDetail += ` (Disc: -${fmtMoney(it.discount)})`;
      }
      bytes.push(...textBytes(`${clip(subDetail, width)}\n`));
    }

    // Match refunds
    const itKey = String(it.product_id || it.id || pName).toLowerCase();
    const matchedRefunds: any[] = [];

    for (const rf of allRefunds) {
      if (!Array.isArray(rf.items)) continue;
      for (const rIt of rf.items) {
        const rKey = String(rIt.product_id || rIt.id || rIt.product_name || '').toLowerCase();
        const nameMatch =
          pName &&
          rIt.product_name &&
          pName.trim().toLowerCase() === rIt.product_name.trim().toLowerCase();
        if ((itKey && rKey && itKey === rKey) || nameMatch) {
          matchedRefunds.push(rIt);
        }
      }
    }

    if (matchedRefunds.length > 0) {
      const itemRefundedQty = matchedRefunds.reduce((sum, r) => sum + (Number(r.quantity) || 1), 0);
      bytes.push(...CMD_BOLD_ON, ...textBytes(`  Refunded: ${itemRefundedQty}x\n`), ...CMD_BOLD_OFF);
    }
  }

  bytes.push(...sep);

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
    bytes.push(...textBytes(padLine('Subtotal', fmtMoney(displaySubtotal), width)));
  }
  if (Number(rawTx.item_discount_total) > 0) {
    bytes.push(...textBytes(padLine('Item Discounts', `-${fmtMoney(rawTx.item_discount_total)}`, width)));
  }
  if (Number(rawTx.overall_discount) > 0) {
    bytes.push(...textBytes(padLine('Overall Discount', `-${fmtMoney(rawTx.overall_discount)}`, width)));
  }
  if (Number(rawTx.tax_amount) > 0 || totalGstRefunded > 0) {
    const displayTax = totalGstRefunded > 0 ? netTax : Number(rawTx.tax_amount);
    bytes.push(...textBytes(padLine('Tax (8%)', fmtMoney(displayTax), width)));
  }

  bytes.push(...dsep);

  if (totalRefunded > 0) {
    bytes.push(...textBytes(padLine('Original Total', fmtMoney(totalAmount), width)));
    bytes.push(...CMD_BOLD_ON, ...textBytes(padLine('TOTAL REFUNDED', `-${fmtMoney(totalRefunded)}`, width)), ...CMD_BOLD_OFF);
    bytes.push(...sep);
    const netRetained = Math.max(0, totalAmount - totalRefunded);
    bytes.push(...CMD_BOLD_ON, ...textBytes(padLine('NET AMOUNT PAID', fmtMoney(netRetained), width)), ...CMD_BOLD_OFF);
  } else {
    bytes.push(...CMD_BOLD_ON, ...textBytes(padLine('GRAND TOTAL', fmtMoney(totalAmount), width)), ...CMD_BOLD_OFF);
  }

  // Cash Tendered & Change
  if (String(rawTx.payment_method).toLowerCase() === 'cash') {
    if (rawTx.amount_tendered !== undefined && Number(rawTx.amount_tendered) > 0) {
      bytes.push(...sep);
      bytes.push(...textBytes(padLine('Amount Tendered', fmtMoney(rawTx.amount_tendered), width)));
      bytes.push(...textBytes(padLine('Change Due', fmtMoney(rawTx.change_amount), width)));
    }
  }

  bytes.push(...sep);

  // 6. Footer (Centered)
  bytes.push(...CMD_ALIGN_CENTER);
  const footerNote = printerSettings?.footer_note || 'Thank you for your visit! Please come again.';
  bytes.push(...textBytes(`${footerNote}\n`));
  bytes.push(...textBytes('Powered by IQ POS\n'));

  // 7. Feed 4 lines
  bytes.push(...textBytes('\n\n\n\n'));

  // 8. Auto cut
  if (printerSettings?.auto_cut !== false) {
    bytes.push(...CMD_CUT);
  }

  // 9. Cash drawer kick (skip drawer kick on reprint)
  if (
    !isReprint &&
    printerSettings?.open_cash_drawer &&
    String(rawTx.payment_method).toLowerCase() === 'cash'
  ) {
    bytes.push(...CMD_CASH_DRAWER);
  }

  return new Uint8Array(bytes);
}
