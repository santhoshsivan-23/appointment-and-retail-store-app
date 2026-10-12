import { toast } from 'react-toastify';
import { settingsApi, type LanPrinterSettings } from '../api/settingsApi';

/* ── Safe Currency Formatter ─────────────────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

export interface ReceiptPrintOptions {
  printerSettings?: LanPrinterSettings | null;
  transaction: any;
  type: 'sale' | 'appointment';
  isReprint?: boolean;
}

/**
 * Generates an HTML thermal receipt string matching the ESC/POS receipt layout.
 * Shows original items with refunded products clearly displayed below them.
 */
export function generateThermalReceiptHtml(
  printerSettings: LanPrinterSettings | null | undefined,
  rawTx: any,
  options: { type: 'sale' | 'appointment'; isReprint?: boolean }
): string {
  const isAppointment = options.type === 'appointment' || Boolean(rawTx.appointment_date || rawTx.services);
  const isReprint = options.isReprint !== undefined ? options.isReprint : true;

  const storeName = printerSettings?.business_name || 'IQ RESTAURANT & POS';
  const addr1 = printerSettings?.addr_line1 || '';
  const addr2 = printerSettings?.addr_line2 || '';
  const addr3 = printerSettings?.addr_line3 || '';
  const phone = printerSettings?.phone_number ? `Tel: ${printerSettings.phone_number}` : '';
  const headerNote = printerSettings?.header_note || 'Tax Invoice / Official Receipt';
  const footerNote = printerSettings?.footer_note || 'Thank you for your visit! Please come again.';

  // Receipt Number
  const receiptNo =
    rawTx.receipt_number ||
    (isAppointment
      ? `#APT-${String(rawTx.id).padStart(4, '0')}`
      : `#REC-${String(rawTx.id).padStart(4, '0')}`);

  // Date and Time
  let dateStr = '';
  let timeStr = '';
  if (isAppointment && rawTx.appointment_date) {
    dateStr = rawTx.appointment_date;
    timeStr = rawTx.start_time
      ? rawTx.end_time
        ? `${rawTx.start_time} - ${rawTx.end_time}`
        : rawTx.start_time
      : '';
  } else {
    const saleDate = rawTx.created_at ? new Date(rawTx.created_at) : new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    dateStr = `${pad(saleDate.getDate())}/${pad(saleDate.getMonth() + 1)}/${saleDate.getFullYear()}`;
    timeStr = `${pad(saleDate.getHours())}:${pad(saleDate.getMinutes())}:${pad(saleDate.getSeconds())}`;
  }

  // Items
  let items: any[] = [];
  if (Array.isArray(rawTx.items) && rawTx.items.length > 0) {
    items = rawTx.items;
  } else if (Array.isArray(rawTx.services) && rawTx.services.length > 0) {
    items = rawTx.services.map((s: any) => ({
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

  // Items rows with refunds
  const itemsHtml = items
    .map((it) => {
      const qty = Number(it.quantity) || 1;
      const unitPrice = Number(it.unit_price) || 0;
      const lineTotal = Number(it.line_total) || unitPrice * qty;
      const pName = it.product_name || it.name || 'Item';

      // Find refunds matching this item
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

      let refundSubBlock = '';
      if (matchedRefunds.length > 0) {
        const itemRefundedQty = matchedRefunds.reduce((sum, r) => sum + r.quantity, 0);
        refundSubBlock = `
          <div class="refund-item-block">
            Refunded: ${itemRefundedQty}x
          </div>
        `;
      }

      return `
        <div class="item-entry">
          <div class="item-primary-row">
            <span class="item-qty">${qty}x</span>
            <span class="item-name">${pName}</span>
            <span class="item-total">$${fmtMoney(lineTotal)}</span>
          </div>
          ${
            qty > 1 || Number(it.discount) > 0
              ? `<div class="item-subdetail">@ $${fmtMoney(unitPrice)}${
                  Number(it.discount) > 0 ? ` (Disc: -$${fmtMoney(it.discount)})` : ''
                }</div>`
              : ''
          }
          ${refundSubBlock}
        </div>
      `;
    })
    .join('');

  // Totals
  const totalAmount = Number(rawTx.total_amount) || 0;
  const totalRefunded =
    Number(rawTx.refunded_amount) ||
    allRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
  const netPaid = Math.max(0, totalAmount - totalRefunded);

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
      : Math.max(0, Math.round(((Number(rawTx.subtotal || rawTx.total_amount) || 0) - totalSubtotalRefunded) * 100) / 100);

  const displaySubtotal = totalRefunded > 0 ? netSubtotal : Number(rawTx.subtotal || rawTx.total_amount);
  const displayTax = totalGstRefunded > 0 ? netTax : Number(rawTx.tax_amount || 0);

  const statusBanner =
    rawTx.refund_status === 'full'
      ? '<div class="banner banner-refund">*** STATUS: FULLY REFUNDED ***</div>'
      : rawTx.refund_status === 'partial'
      ? '<div class="banner banner-partial">*** STATUS: PARTIALLY REFUNDED ***</div>'
      : '<div class="banner banner-completed">*** STATUS: COMPLETED ***</div>';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt - ${receiptNo}</title>
  <style>
    @page {
      margin: 4mm;
      size: 80mm auto;
    }
    body {
      font-family: 'Courier New', Courier, monospace, -apple-system, BlinkMacSystemFont, sans-serif;
      width: 76mm;
      max-width: 320px;
      margin: 0 auto;
      padding: 8px 6px;
      color: #000;
      font-size: 11.5px;
      line-height: 1.35;
      background: #fff;
      box-sizing: border-box;
    }
    .center { text-align: center; }
    .right { text-align: right; }
    .bold { font-weight: bold; }
    .store-title {
      font-size: 14.5px;
      font-weight: 800;
      letter-spacing: 0.5px;
      margin-bottom: 2px;
    }
    .header-note {
      font-size: 10px;
      font-weight: 600;
      margin-top: 3px;
    }
    .divider {
      border-top: 1px dashed #000;
      margin: 6px 0;
    }
    .d-divider {
      border-top: 2px double #000;
      margin: 6px 0;
    }
    .banner {
      font-weight: 800;
      text-align: center;
      margin: 3px 0;
      font-size: 11px;
    }
    .banner-reprint {
      border: 1px solid #000;
      padding: 2px 4px;
      letter-spacing: 0.5px;
    }
    .banner-refund {
      color: #000;
      font-style: italic;
    }
    .meta-row {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      margin: 1px 0;
    }
    .item-headers {
      display: flex;
      font-weight: bold;
      border-bottom: 1px solid #000;
      padding-bottom: 3px;
      margin-bottom: 4px;
    }
    .item-entry {
      margin-bottom: 5px;
    }
    .item-primary-row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
    }
    .item-qty {
      width: 28px;
      font-weight: bold;
      flex-shrink: 0;
    }
    .item-name {
      flex: 1;
      padding-right: 4px;
      word-break: break-word;
    }
    .item-total {
      text-align: right;
      font-weight: 600;
      flex-shrink: 0;
    }
    .item-subdetail {
      font-size: 10px;
      padding-left: 28px;
      color: #333;
    }
    .refund-item-block {
      margin-top: 1px;
      padding-left: 28px;
      font-size: 11px;
      font-weight: bold;
      color: #000;
    }
    .totals-row {
      display: flex;
      justify-content: space-between;
      margin: 2px 0;
    }
    .grand-total-row {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      font-weight: 800;
      margin: 4px 0;
    }
    .refund-total-row {
      display: flex;
      justify-content: space-between;
      font-weight: bold;
    }
    .footer-text {
      text-align: center;
      margin-top: 10px;
      font-size: 10.5px;
    }
  </style>
</head>
<body>
  <div class="center store-title">${storeName}</div>
  ${addr1 ? `<div class="center">${addr1}</div>` : ''}
  ${addr2 ? `<div class="center">${addr2}</div>` : ''}
  ${addr3 ? `<div class="center">${addr3}</div>` : ''}
  ${phone ? `<div class="center">${phone}</div>` : ''}
  ${headerNote ? `<div class="center header-note">${headerNote}</div>` : ''}

  ${
    isReprint
      ? `
      <div class="divider"></div>
      <div class="banner banner-reprint">*** REPRINT RECEIPT ***</div>
      ${statusBanner}
      `
      : ''
  }

  <div class="divider"></div>

  <div class="meta-row">
    <span>Date: ${dateStr}</span>
    <span>Time: ${timeStr}</span>
  </div>
  <div class="meta-row">
    <span>Receipt: ${receiptNo}</span>
    <span>Pay: ${(rawTx.payment_method || 'CASH').toUpperCase()}</span>
  </div>
  ${
    rawTx.staff_name
      ? `<div class="meta-row"><span>${
          isAppointment ? 'Attendant' : 'Cashier'
        }: ${rawTx.staff_name}</span></div>`
      : ''
  }
  ${
    rawTx.customer_name && rawTx.customer_name !== 'Walk-in'
      ? `<div class="meta-row"><span>Customer: ${rawTx.customer_name}${
          rawTx.customer_phone ? ` (${rawTx.customer_phone})` : ''
        }</span></div>`
      : ''
  }

  <div class="divider"></div>

  <div class="item-headers">
    <span style="width: 28px;">Qty</span>
    <span style="flex: 1;">Item</span>
    <span style="text-align: right;">Price</span>
  </div>

  ${itemsHtml}

  <div class="divider"></div>

  ${
    rawTx.subtotal !== undefined
      ? `<div class="totals-row"><span>Subtotal:</span><span>$${fmtMoney(
          displaySubtotal
        )}</span></div>`
      : ''
  }
  ${
    Number(rawTx.item_discount_total) > 0
      ? `<div class="totals-row"><span>Item Discounts:</span><span>-$${fmtMoney(
          rawTx.item_discount_total
        )}</span></div>`
      : ''
  }
  ${
    Number(rawTx.overall_discount) > 0
      ? `<div class="totals-row"><span>Overall Discount:</span><span>-$${fmtMoney(
          rawTx.overall_discount
        )}</span></div>`
      : ''
  }
  ${
    Number(rawTx.tax_amount) > 0 || totalGstRefunded > 0
      ? `<div class="totals-row"><span>Tax (8%):</span><span>$${fmtMoney(
          displayTax
        )}</span></div>`
      : ''
  }

  <div class="d-divider"></div>

  ${
    totalRefunded > 0
      ? `
      <div class="totals-row"><span>Original Total:</span><span>$${fmtMoney(
          totalAmount
        )}</span></div>
      <div class="refund-total-row"><span>TOTAL REFUNDED:</span><span>-$${fmtMoney(
          totalRefunded
        )}</span></div>
      <div class="divider"></div>
      <div class="grand-total-row"><span>NET AMOUNT:</span><span>$${fmtMoney(
          netPaid
        )}</span></div>
      `
      : `
      <div class="grand-total-row"><span>GRAND TOTAL:</span><span>$${fmtMoney(
          totalAmount
        )}</span></div>
      `
  }

  ${
    String(rawTx.payment_method).toLowerCase() === 'cash' &&
    rawTx.amount_tendered !== undefined &&
    Number(rawTx.amount_tendered) > 0
      ? `
      <div class="divider"></div>
      <div class="totals-row"><span>Amount Tendered:</span><span>$${fmtMoney(
          rawTx.amount_tendered
        )}</span></div>
      <div class="totals-row"><span>Change Due:</span><span>$${fmtMoney(
          rawTx.change_amount
        )}</span></div>
      `
      : ''
  }

  <div class="divider"></div>

  <div class="footer-text">
    <div>${footerNote}</div>
    <div style="font-size: 9.5px; color: #555; margin-top: 3px;">Powered by IQ POS</div>
  </div>

  <script>
    window.onload = function() {
      window.print();
      setTimeout(function() {
        window.close();
      }, 1000);
    };
  </script>
</body>
</html>
  `;
}

/**
 * Opens a clean browser print popup dialog with the thermal receipt.
 */
export function openBrowserReceiptPrintDialog(
  printerSettings: LanPrinterSettings | null | undefined,
  rawTx: any,
  options: { type: 'sale' | 'appointment'; isReprint?: boolean }
): void {
  const htmlContent = generateThermalReceiptHtml(printerSettings, rawTx, options);
  const printWindow = window.open('', '_blank', 'width=380,height=600,top=100,left=100');
  if (!printWindow) {
    toast.error('Could not open print window. Please allow popups for this site.');
    return;
  }
  printWindow.document.open();
  printWindow.document.write(htmlContent);
  printWindow.document.close();
}

/**
 * Universal print handler:
 * Dispatches the receipt to the configured LAN printer using existing receipt printing functionality.
 * If the LAN printer is offline, not configured, or fails to respond, it automatically falls back
 * to the browser print window so printing is never blocked.
 */
export async function executeReceiptPrint({
  printerSettings,
  transaction,
  type,
  isReprint = true,
}: ReceiptPrintOptions): Promise<boolean> {
  const isLanEnabled = printerSettings?.is_enabled !== false;
  const isReceiptEnabled = printerSettings?.order_receipt_enabled !== false;
  const hasIp = Boolean(printerSettings?.ip_address && printerSettings.ip_address.trim());

  // If LAN printer is not configured or disabled, fall back directly to browser print
  if (!isLanEnabled || !isReceiptEnabled || !hasIp) {
    toast.info('LAN printer is not configured or disabled. Opening print preview...');
    openBrowserReceiptPrintDialog(printerSettings, transaction, { type, isReprint });
    return true;
  }

  try {
    const res = await settingsApi.printReceipt({
      printer_settings: printerSettings || undefined,
      [type === 'appointment' ? 'appointment' : 'sale']: transaction,
      type,
      is_reprint: isReprint,
    });

    if (res.data?.success) {
      toast.success(
        res.data.message ||
          `${type === 'appointment' ? 'Appointment' : 'Sales'} receipt printed on LAN printer.`
      );
      return true;
    } else {
      const warnMsg = res.data?.message || 'LAN printer did not respond.';
      toast.warn(`${warnMsg} Opening print preview...`);
      openBrowserReceiptPrintDialog(printerSettings, transaction, { type, isReprint });
      return true;
    }
  } catch (err: any) {
    console.error('Error printing receipt to LAN printer:', err);
    const errMsg = err.response?.data?.message || err.message || 'LAN printer connection failed';
    toast.warn(`${errMsg}. Opening print preview...`);
    openBrowserReceiptPrintDialog(printerSettings, transaction, { type, isReprint });
    return true;
  }
}
