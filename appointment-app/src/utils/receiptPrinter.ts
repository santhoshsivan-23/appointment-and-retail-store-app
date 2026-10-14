import { toast } from 'react-toastify';
import type { LanPrinterSettings } from '../api/settingsApi';
import { buildEscPosTestPrint, buildEscPosOrderReceipt } from './escPosBuilder';

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
 * Checks whether the current React application is running on localhost/LAN.
 */
export function isLocalhost(): boolean {
  if (typeof window === 'undefined') return true;
  const host = window.location.hostname;
  return (
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host === '0.0.0.0' ||
    host.endsWith('.local')
  );
}

/**
 * Checks whether an IP address belongs to RFC 1918 private / local networks.
 */
export function isPrivateIp(ip?: string | null): boolean {
  if (!ip) return false;
  const trimmed = ip.trim();
  return (
    trimmed.startsWith('192.168.') ||
    trimmed.startsWith('10.') ||
    trimmed.startsWith('127.') ||
    /^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(trimmed)
  );
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

  const is58 = printerSettings?.paper_size === 'mm58';
  const pageSizeCss = is58 ? '58mm auto' : '80mm auto';
  const bodyWidthCss = is58 ? '54mm' : '76mm';
  const maxWidthCss = is58 ? '230px' : '320px';
  const fontSizeCss = is58 ? '10px' : '11.5px';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt - ${receiptNo}</title>
  <style>
    @page {
      margin: 3mm;
      size: ${pageSizeCss};
    }
    body {
      font-family: 'Courier New', Courier, monospace, -apple-system, BlinkMacSystemFont, sans-serif;
      width: ${bodyWidthCss};
      max-width: ${maxWidthCss};
      margin: 0 auto;
      padding: 6px 4px;
      color: #000;
      font-size: ${fontSizeCss};
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
    window.addEventListener('load', function() {
      if (window.opener || window.name === 'receipt_print_popup') {
        window.focus();
        window.print();
        setTimeout(function() {
          window.close();
        }, 1200);
      }
    });
  </script>
</body>
</html>
  `;
}

/**
 * Prints thermal receipt HTML silently via a hidden iframe.
 * Unlike window.open, this is NEVER blocked by browser pop-up blockers,
 * even when called asynchronously after network requests or checkout.
 */
export function printReceiptViaIframe(htmlContent: string): boolean {
  try {
    let iframe = document.getElementById('pos-receipt-print-frame') as HTMLIFrameElement | null;
    if (iframe) {
      iframe.remove();
    }
    iframe = document.createElement('iframe');
    iframe.id = 'pos-receipt-print-frame';
    iframe.name = 'pos_receipt_print_frame';
    iframe.style.position = 'fixed';
    iframe.style.top = '-9999px';
    iframe.style.left = '-9999px';
    iframe.style.width = '80mm';
    iframe.style.height = '100mm';
    iframe.style.border = 'none';
    iframe.style.visibility = 'hidden';
    document.body.appendChild(iframe);

    const doc = iframe.contentDocument || iframe.contentWindow?.document;
    if (!doc) {
      return false;
    }

    doc.open();
    doc.write(htmlContent);
    doc.close();

    setTimeout(() => {
      try {
        iframe?.contentWindow?.focus();
        iframe?.contentWindow?.print();
      } catch (err) {
        console.warn('Iframe print error, falling back to popup window:', err);
        fallbackPopup(htmlContent);
      }
    }, 250);
    return true;
  } catch (err) {
    console.error('Failed to create print iframe:', err);
    return false;
  }
}

function fallbackPopup(htmlContent: string): void {
  const printWindow = window.open('', 'receipt_print_popup', 'width=380,height=600,top=100,left=100');
  if (!printWindow) {
    toast.error('Could not open print window. Please allow popups for this site.');
    return;
  }
  printWindow.document.open();
  printWindow.document.write(htmlContent);
  printWindow.document.close();
}

/**
 * Opens a clean browser print dialog with the thermal receipt.
 * Uses a non-blocking hidden iframe with fallback to window.open.
 */
export function openBrowserReceiptPrintDialog(
  printerSettings: LanPrinterSettings | null | undefined,
  rawTx: any,
  options: { type: 'sale' | 'appointment'; isReprint?: boolean }
): void {
  const htmlContent = generateThermalReceiptHtml(printerSettings, rawTx, options);
  const printed = printReceiptViaIframe(htmlContent);
  if (!printed) {
    fallbackPopup(htmlContent);
  }
}

/**
 * Generates and prints a clean "Test Printing" receipt via browser dialog.
 */
export function openBrowserTestPrint(printerSettings?: LanPrinterSettings | null): void {
  const is58 = printerSettings?.paper_size === 'mm58';
  const rollWidth = is58 ? '58mm' : '80mm';
  const bodyWidth = is58 ? '54mm' : '76mm';
  const maxWidth = is58 ? '230px' : '320px';
  const fontSize = is58 ? '10px' : '11.5px';

  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  const formattedDate = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}`;
  const formattedTime = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;

  const htmlContent = `
    <!DOCTYPE html>
    <html>
      <head>
        <title>Test Printing - ${printerSettings?.printer_name || 'POS'}</title>
        <style>
          @page { size: ${rollWidth} auto; margin: 3mm; }
          body {
            font-family: 'Courier New', Courier, monospace;
            font-size: ${fontSize};
            width: ${bodyWidth};
            max-width: ${maxWidth};
            margin: 0 auto;
            padding: 8px 6px;
            color: #000;
            background: #fff;
            line-height: 1.35;
          }
          .center { text-align: center; }
          .bold { font-weight: bold; }
          .title { font-size: ${is58 ? '17px' : '20px'}; font-weight: 900; margin: 6px 0; letter-spacing: 0.5px; }
          .store { font-size: 13.5px; font-weight: bold; margin-bottom: 3px; }
          .divider { border-bottom: 1px dashed #000; margin: 6px 0; }
          .solid-divider { border-bottom: 1px solid #000; margin: 6px 0; }
          .row { display: flex; justify-content: space-between; margin: 2px 0; }
          .footer { margin-top: 10px; font-size: 10.5px; text-align: center; }
        </style>
      </head>
      <body>
        <div class="center store">${printerSettings?.business_name || 'IQ Restaurant POS'}</div>
        ${printerSettings?.addr_line1 ? `<div class="center">${printerSettings.addr_line1}</div>` : ''}
        ${printerSettings?.phone_number ? `<div class="center">Tel: ${printerSettings.phone_number}</div>` : ''}
        <div class="divider"></div>
        <div class="center bold title">Test Printing</div>
        <div class="divider"></div>
        <div class="row"><span>Date:</span><span>${formattedDate}</span></div>
        <div class="row"><span>Time:</span><span>${formattedTime}</span></div>
        <div class="solid-divider"></div>
        <div class="row"><span>Printer:</span><span>${printerSettings?.printer_name || 'Main Counter LAN Printer'}</span></div>
        <div class="row"><span>IP Address:</span><span>${printerSettings?.ip_address || '192.168.1.51'}:${printerSettings?.port || 9100}</span></div>
        <div class="row"><span>Roll Size:</span><span>${is58 ? '58mm Roll (32 col)' : '80mm Roll (48 col)'}</span></div>
        <div class="row"><span>Mode:</span><span>${isLocalhost() ? 'Local Network' : 'Web / Cloud Spooler'}</span></div>
        <div class="divider"></div>
        <div class="center bold" style="margin: 8px 0;">*** TEST PRINT COMPLETED ***</div>
        <div class="center footer">Powered by IQ POS</div>
        <script>
          window.addEventListener('load', function() {
            if (window.opener || window.name === 'receipt_print_popup') {
              window.focus();
              window.print();
              setTimeout(function() { window.close(); }, 1200);
            }
          });
        </script>
      </body>
    </html>
  `;

  const printed = printReceiptViaIframe(htmlContent);
  if (!printed) {
    fallbackPopup(htmlContent);
  }
}

/**
 * Sends raw ESC/POS binary data directly to the LAN printer over TCP socket.
 */
export async function sendRawToLanPrinter(
  rawBytes: Uint8Array,
  printerSettings?: LanPrinterSettings | null
): Promise<{ success: boolean; message: string }> {
  const ip = (printerSettings?.ip_address || '192.168.1.51').trim();
  const port = Number(printerSettings?.port) || 9100;
  const printMethod = printerSettings?.print_method || 'auto';

  if (printMethod === 'browser') {
    return {
      success: false,
      message: 'Browser print mode is selected in settings.',
    };
  }

  // Check if we are running in cloud and printer is a private LAN IP
  const localEnv = isLocalhost();
  const privateIp = isPrivateIp(ip);

  // If website is on HTTPS and attempting to connect to HTTP localhost, browsers block it (mixed content).
  // If deployed in cloud without a local bridge, skip immediately.
  if (!localEnv && privateIp && printMethod !== 'lan_socket') {
    return {
      success: false,
      message: 'Cloud deployment detected: Direct TCP socket cannot reach private LAN IP.',
    };
  }

  // Convert Uint8Array to base64 string
  let binary = '';
  const len = rawBytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(rawBytes[i]);
  }
  const rawBase64 = window.btoa(binary);

  const payload = {
    ip_address: ip,
    port,
    raw_base64: rawBase64,
  };

  // Try endpoints
  const candidateUrls = [
    '/api/printer/raw',
    'http://localhost:5001/api/printer/raw',
    'http://localhost:5000/api/printer/raw',
  ];

  let lastError = `LAN printer at ${ip}:${port} did not answer.`;

  for (const url of candidateUrls) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2000);

      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      clearTimeout(timeoutId);

      if (res.ok) {
        const data = await res.json();
        if (data.success) {
          return {
            success: true,
            message: data.message || `Printed to LAN printer at ${ip}:${port}!`,
          };
        } else {
          lastError = data.message || lastError;
        }
      } else {
        const errJson = await res.json().catch(() => null);
        if (errJson?.message) {
          lastError = errJson.message;
        }
      }
    } catch (e: any) {
      lastError = e.message || lastError;
    }
  }

  return {
    success: false,
    message: lastError,
  };
}

/**
 * Triggers a test print.
 * If direct socket printing fails or if running on a deployed website,
 * it automatically falls back to browser print so testing NEVER fails!
 */
export async function executeTestPrint(
  printerSettings?: LanPrinterSettings | null
): Promise<{ success: boolean; message: string }> {
  const ip = (printerSettings?.ip_address || '192.168.1.51').trim();
  const port = Number(printerSettings?.port) || 9100;
  const printMethod = printerSettings?.print_method || 'auto';

  const localEnv = isLocalhost();
  const privateIp = isPrivateIp(ip);

  // If deployed in cloud and on private LAN IP:
  if (!localEnv && privateIp && printMethod !== 'lan_socket') {
    toast.info('Cloud Deployment: Opening print dialog for test receipt...');
    openBrowserTestPrint(printerSettings);
    return {
      success: true,
      message: `Cloud Deployment Mode: Test receipt opened in browser print dialog for ${printerSettings?.printer_name || 'LAN Printer'}.`,
    };
  }

  try {
    const rawEscPos = buildEscPosTestPrint(printerSettings);
    const result = await sendRawToLanPrinter(rawEscPos, printerSettings);

    if (result.success) {
      toast.success(result.message || `Test receipt printed on LAN printer at ${ip}:${port}!`);
      return { success: true, message: result.message };
    } else {
      // Automatic fallback to browser print dialog
      toast.warn('Direct LAN socket unavailable. Opening print dialog...');
      openBrowserTestPrint(printerSettings);
      return {
        success: true,
        message: 'Opened in browser print dialog (LAN socket unavailable).',
      };
    }
  } catch (err: any) {
    const errMsg = err.message || String(err);
    toast.warn(`Direct print socket error: ${errMsg}. Opening print dialog...`);
    openBrowserTestPrint(printerSettings);
    return { success: true, message: 'Opened in browser print dialog.' };
  }
}

/**
 * Universal direct receipt print handler:
 * - When in cloud deployment or when print_method is 'browser', dispatches seamlessly via browser print.
 * - When in local network, attempts raw socket first; if offline, automatically falls back to browser print.
 * - Printing is NEVER blocked or lost!
 */
export async function executeReceiptPrint({
  printerSettings,
  transaction,
  type,
  isReprint = true,
}: ReceiptPrintOptions): Promise<boolean> {
  if (!transaction) return false;

  const isEnabled = printerSettings?.is_enabled !== false;
  const isReceiptEnabled = printerSettings?.order_receipt_enabled !== false;

  if (!isEnabled) {
    toast.info('Printer is toggled off in Printer Settings.');
    return false;
  }

  if (!isReceiptEnabled && !isReprint) {
    console.log('Customer Order Receipt printing is disabled in settings; print skipped.');
    return false;
  }

  const ip = (printerSettings?.ip_address || '192.168.1.51').trim();
  const port = Number(printerSettings?.port) || 9100;
  const printMethod = printerSettings?.print_method || 'auto';

  // 1. If explicit browser method is selected:
  if (printMethod === 'browser') {
    openBrowserReceiptPrintDialog(printerSettings, transaction, { type, isReprint });
    return true;
  }

  // 2. Check if deployed on a cloud/remote website
  const localEnv = isLocalhost();
  const privateIp = isPrivateIp(ip);

  // In cloud deployment with private LAN IP, bypass socket timeout and print directly:
  if (!localEnv && privateIp && printMethod !== 'lan_socket') {
    toast.info(
      `Website deployed in cloud: Opening print dialog for ${printerSettings?.printer_name || 'LAN Printer'}...`
    );
    openBrowserReceiptPrintDialog(printerSettings, transaction, { type, isReprint });
    return true;
  }

  // 3. Attempt direct raw ESC/POS socket
  try {
    const rawEscPos = buildEscPosOrderReceipt(printerSettings, transaction, { type, isReprint });
    const result = await sendRawToLanPrinter(rawEscPos, printerSettings);

    if (result.success) {
      toast.success(
        `${type === 'appointment' ? 'Appointment' : 'Sales'} receipt printed directly to LAN printer (${ip}:${port})!`
      );
      return true;
    } else {
      // Auto fallback to browser print dialog
      toast.warn('LAN printer did not respond directly. Opening print dialog...');
      openBrowserReceiptPrintDialog(printerSettings, transaction, { type, isReprint });
      return true;
    }
  } catch (err: any) {
    console.error('Error in executeReceiptPrint:', err);
    toast.warn('Printer socket error. Opening print dialog...');
    openBrowserReceiptPrintDialog(printerSettings, transaction, { type, isReprint });
    return true;
  }
}
