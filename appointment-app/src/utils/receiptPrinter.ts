import { toast } from 'react-toastify';
import type { LanPrinterSettings } from '../api/settingsApi';
import { buildEscPosTestPrint, buildEscPosOrderReceipt } from './escPosBuilder';

export interface ReceiptPrintOptions {
  printerSettings?: LanPrinterSettings | null;
  transaction: any;
  type: 'sale' | 'appointment';
  isReprint?: boolean;
}

/**
 * Sends raw ESC/POS binary data directly to the LAN printer over TCP socket.
 * Dispatches silently in the background without EVER opening any browser print window.
 */
export async function sendRawToLanPrinter(
  rawBytes: Uint8Array,
  printerSettings?: LanPrinterSettings | null
): Promise<{ success: boolean; message: string }> {
  const ip = (printerSettings?.ip_address || '192.168.1.51').trim();
  const port = Number(printerSettings?.port) || 9100;

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

  // Try Vite dev server middleware endpoint first, then standalone local bridges
  const candidateUrls = [
    '/api/printer/raw',
    'http://localhost:5001/api/printer/raw',
    'http://localhost:5000/api/printer/raw',
  ];

  let lastError = `LAN printer at ${ip}:${port} did not answer.`;

  for (const url of candidateUrls) {
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

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
 * Triggers a test print directly to the LAN printer without opening any print window.
 */
export async function executeTestPrint(
  printerSettings?: LanPrinterSettings | null
): Promise<{ success: boolean; message: string }> {
  const ip = (printerSettings?.ip_address || '192.168.1.51').trim();
  const port = Number(printerSettings?.port) || 9100;

  try {
    const rawEscPos = buildEscPosTestPrint(printerSettings);
    const result = await sendRawToLanPrinter(rawEscPos, printerSettings);

    if (result.success) {
      toast.success(result.message || `Test receipt printed on LAN printer at ${ip}:${port}!`);
      return { success: true, message: result.message };
    } else {
      toast.error(`Direct print failed: ${result.message}`);
      return { success: false, message: result.message };
    }
  } catch (err: any) {
    const errMsg = err.message || String(err);
    toast.error(`Failed to dispatch test print: ${errMsg}`);
    return { success: false, message: errMsg };
  }
}

/**
 * Universal direct receipt print handler:
 * Dispatches receipt directly to the LAN printer over TCP socket without opening any print window.
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

  try {
    const rawEscPos = buildEscPosOrderReceipt(printerSettings, transaction, { type, isReprint });
    const result = await sendRawToLanPrinter(rawEscPos, printerSettings);

    if (result.success) {
      toast.success(
        `${type === 'appointment' ? 'Appointment' : 'Sales'} receipt printed directly to LAN printer (${ip}:${port})!`
      );
      return true;
    } else {
      toast.error(`LAN print failed: ${result.message}`);
      return false;
    }
  } catch (err: any) {
    console.error('Error in executeReceiptPrint:', err);
    toast.error(`Print error: ${err.message || 'Could not dispatch print'}`);
    return false;
  }
}

/**
 * Manual preview dialog (only if user explicitly clicks preview).
 * Never opened automatically during checkout or Test Print.
 */
export function openBrowserReceiptPrintDialog(
  _printerSettings: LanPrinterSettings | null | undefined,
  _rawTx: any,
  _options: { type: 'sale' | 'appointment'; isReprint?: boolean }
): void {
  toast.info('Direct LAN printing is enabled. Thermal receipts are sent directly to the printer.');
}
