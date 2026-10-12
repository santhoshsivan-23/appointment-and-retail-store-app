import { useState, useEffect } from 'react';
import { toast } from 'react-toastify';
import {
  Printer,
  Wifi,
  Save,
  CheckCircle2,
  AlertCircle,
  Radio,
  Store,
  Layers,
  FileText,
  Check,
  RefreshCw,
} from 'lucide-react';
import { settingsApi, type LanPrinterSettings } from '../api/settingsApi';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import { setPrinterSettings } from '../features/printer/printerSlice';
import '../styles/printer_settings.css';

const DEFAULT_PRINTER_SETTINGS: LanPrinterSettings = {
  printer_name: 'Main Counter LAN Printer',
  connection_type: 'lan',
  ip_address: '192.168.1.100',
  port: 9100,
  paper_size: 'mm80',
  business_name: 'IQ Store',
  phone_number: '+1 (555) 019-2834',
  addr_line1: '100 Terminal Boulevard',
  addr_line2: 'Suite 400',
  addr_line3: 'New York, NY 10001',
  addr_line4: 'Tax ID: US-987654321',
  header_note: 'Tax Invoice / Official Receipt',
  footer_note: 'Thank you for your visit! Please come again.',
  is_default: true,
  is_enabled: true,
  order_receipt_enabled: true,
  auto_cut: true,
  open_cash_drawer: false,
};

export default function PrinterSettingsView() {
  const dispatch = useAppDispatch();
  const business = useAppSelector((s) => s.auth.business);
  const authBusinessName =
    business?.business_name?.trim() ||
    business?.owner_name?.trim() ||
    'IQ Store';

  /* ── Form States ────────────────────────────────────────── */
  const [printerName, setPrinterName] = useState<string>(DEFAULT_PRINTER_SETTINGS.printer_name);
  const [connectionType, setConnectionType] = useState<'lan' | 'usb'>('lan');
  const [ipAddress, setIpAddress] = useState<string>(DEFAULT_PRINTER_SETTINGS.ip_address);
  const [port, setPort] = useState<number>(DEFAULT_PRINTER_SETTINGS.port);
  const [paperSize, setPaperSize] = useState<'mm80' | 'mm58'>('mm80');
  const [businessName, setBusinessName] = useState<string>(authBusinessName);
  const [phoneNumber, setPhoneNumber] = useState<string>(DEFAULT_PRINTER_SETTINGS.phone_number || '');
  const [addrLine1, setAddrLine1] = useState<string>(DEFAULT_PRINTER_SETTINGS.addr_line1 || '');
  const [addrLine2, setAddrLine2] = useState<string>(DEFAULT_PRINTER_SETTINGS.addr_line2 || '');
  const [addrLine3, setAddrLine3] = useState<string>(DEFAULT_PRINTER_SETTINGS.addr_line3 || '');
  const [addrLine4, setAddrLine4] = useState<string>(DEFAULT_PRINTER_SETTINGS.addr_line4 || '');
  const [headerNote, setHeaderNote] = useState<string>(DEFAULT_PRINTER_SETTINGS.header_note || '');
  const [footerNote, setFooterNote] = useState<string>(DEFAULT_PRINTER_SETTINGS.footer_note || '');
  const [isDefault, setIsDefault] = useState<boolean>(true);
  const [isEnabled, setIsEnabled] = useState<boolean>(true);
  const [orderReceiptEnabled, setOrderReceiptEnabled] = useState<boolean>(true);
  const [autoCut, setAutoCut] = useState<boolean>(true);
  const [openCashDrawer, setOpenCashDrawer] = useState<boolean>(false);

  /* ── Status & Network States ────────────────────────────── */
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSaving, setIsSaving] = useState<boolean>(false);
  const [isTesting, setIsTesting] = useState<boolean>(false);
  const [testResult, setTestResult] = useState<{
    status: 'success' | 'error' | 'testing' | null;
    message: string;
  }>({ status: null, message: '' });
  const [previewTab, setPreviewTab] = useState<'customer' | 'test'>('customer');

  /* ── Load Saved Printer Settings ────────────────────────── */
  useEffect(() => {
    async function loadSettings() {
      setIsLoading(true);
      try {
        // 1. Try fetching from Backend API
        const res = await settingsApi.getSettings();
        const serverData = res.data?.data?.printer_settings;

        let parsed: LanPrinterSettings | null = null;
        if (serverData) {
          parsed =
            typeof serverData === 'string'
              ? (() => {
                  try {
                    return JSON.parse(serverData);
                  } catch {
                    return null;
                  }
                })()
              : serverData;
        }

        // 2. Fallback to localStorage if server has no printer_settings yet
        if (!parsed) {
          const cached = localStorage.getItem('iq_printer_settings');
          if (cached) {
            try {
              parsed = JSON.parse(cached);
            } catch {
              parsed = null;
            }
          }
        }

        const effective = parsed || DEFAULT_PRINTER_SETTINGS;
        setPrinterName(effective.printer_name || DEFAULT_PRINTER_SETTINGS.printer_name);
        setConnectionType(effective.connection_type || 'lan');
        setIpAddress(effective.ip_address || DEFAULT_PRINTER_SETTINGS.ip_address);
        setPort(Number(effective.port) || 9100);
        setPaperSize(effective.paper_size === 'mm58' ? 'mm58' : 'mm80');
        setBusinessName(effective.business_name || authBusinessName);
        setPhoneNumber(effective.phone_number || DEFAULT_PRINTER_SETTINGS.phone_number || '');
        setAddrLine1(effective.addr_line1 || DEFAULT_PRINTER_SETTINGS.addr_line1 || '');
        setAddrLine2(effective.addr_line2 || DEFAULT_PRINTER_SETTINGS.addr_line2 || '');
        setAddrLine3(effective.addr_line3 || DEFAULT_PRINTER_SETTINGS.addr_line3 || '');
        setAddrLine4(effective.addr_line4 || DEFAULT_PRINTER_SETTINGS.addr_line4 || '');
        setHeaderNote(effective.header_note || DEFAULT_PRINTER_SETTINGS.header_note || '');
        setFooterNote(effective.footer_note || DEFAULT_PRINTER_SETTINGS.footer_note || '');
        setIsDefault(effective.is_default !== undefined ? effective.is_default : true);
        setIsEnabled(effective.is_enabled !== undefined ? effective.is_enabled : true);
        setOrderReceiptEnabled(
          effective.order_receipt_enabled !== undefined ? effective.order_receipt_enabled : true
        );
        setAutoCut(effective.auto_cut !== undefined ? effective.auto_cut : true);
        setOpenCashDrawer(effective.open_cash_drawer !== undefined ? effective.open_cash_drawer : false);
      } catch (err) {
        console.warn('Could not load settings from server, falling back to local defaults:', err);
      } finally {
        setIsLoading(false);
      }
    }

    loadSettings();
  }, [authBusinessName]);

  /* ── Validate LAN IP ────────────────────────────────────── */
  const isValidIpv4 = (ip: string) => {
    const regex =
      /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    return regex.test(ip.trim());
  };

  /* ── Save Printer Configuration ─────────────────────────── */
  const handleSaveSettings = async () => {
    if (!printerName.trim()) {
      toast.error('Printer name cannot be blank.');
      return;
    }

    if (connectionType === 'lan') {
      if (!ipAddress.trim()) {
        toast.error('LAN Printer IP address is required.');
        return;
      }
      if (!isValidIpv4(ipAddress)) {
        toast.error('Invalid IPv4 address format (e.g. 192.168.1.100).');
        return;
      }
      if (!port || port < 1 || port > 65535) {
        toast.error('Port must be a valid number between 1 and 65535 (Default is 9100).');
        return;
      }
    }

    setIsSaving(true);
    const payload: LanPrinterSettings = {
      printer_name: printerName.trim(),
      connection_type: connectionType,
      ip_address: ipAddress.trim(),
      port: Number(port) || 9100,
      paper_size: paperSize,
      business_name: businessName.trim(),
      phone_number: phoneNumber.trim(),
      addr_line1: addrLine1.trim(),
      addr_line2: addrLine2.trim(),
      addr_line3: addrLine3.trim(),
      addr_line4: addrLine4.trim(),
      header_note: headerNote.trim(),
      footer_note: footerNote.trim(),
      is_default: isDefault,
      is_enabled: isEnabled,
      order_receipt_enabled: orderReceiptEnabled,
      auto_cut: autoCut,
      open_cash_drawer: openCashDrawer,
    };

    try {
      // 1. Save to Backend API
      await settingsApi.updateSettings({
        printer_settings: payload,
      });

      // 2. Persist in local storage and update Redux shared memory immediately
      dispatch(setPrinterSettings(payload));
      localStorage.setItem('iq_printer_settings', JSON.stringify(payload));

      toast.success('Printer settings saved and applied!');
    } catch (err: any) {
      console.error('Failed to update server settings:', err);
      // Persist locally & Redux even if server is offline
      dispatch(setPrinterSettings(payload));
      localStorage.setItem('iq_printer_settings', JSON.stringify(payload));
      toast.info('Settings saved locally in terminal storage.');
    } finally {
      setIsSaving(false);
    }
  };

  /* ── Test Print Handler ────────────────────────────── */
  const handleTestPrint = async () => {
    if (connectionType === 'lan' && !isValidIpv4(ipAddress)) {
      toast.error('Please enter a valid IPv4 address before testing.');
      return;
    }

    setIsTesting(true);
    setTestResult({
      status: 'testing',
      message: `Sending "Test Printing" command to LAN printer at ${ipAddress}:${port}...`,
    });

    try {
      const res = await settingsApi.testPrint({
        ip_address: ipAddress.trim(),
        port: Number(port) || 9100,
        printer_name: printerName.trim(),
        business_name: businessName.trim(),
        paper_size: paperSize,
        auto_cut: autoCut,
        open_cash_drawer: openCashDrawer,
        test_text: 'Test Printing',
      });

      if (res.data?.success) {
        setTestResult({
          status: 'success',
          message:
            res.data.message ||
            `Successfully printed "Test Printing" on LAN printer at ${ipAddress}:${port}!`,
        });
        toast.success(`"Test Printing" sent to LAN printer at ${ipAddress}:${port}`);
      } else {
        setTestResult({
          status: 'error',
          message:
            res.data?.message ||
            `LAN printer at ${ipAddress}:${port} did not answer within timeout.`,
        });
        toast.warn(
          res.data?.message ||
            'LAN printer did not respond. You can test print using the system printer below.'
        );
      }
    } catch (err: any) {
      const msg = err.response?.data?.message || err.message || 'Network socket error';
      setTestResult({
        status: 'error',
        message: `Socket error: ${msg}. Make sure the printer is turned on and on the same LAN network.`,
      });
      toast.error(`Could not connect to ${ipAddress}:${port}. Use "Print via System" to test local printing.`);
    } finally {
      setIsTesting(false);
    }
  };

  /* ── Browser / System Print Handler for "Test Printing" ── */
  const handleBrowserTestPrint = () => {
    const is58 = paperSize === 'mm58';
    const rollWidth = is58 ? '58mm' : '80mm';
    const printWindow = window.open('', '_blank', 'width=420,height=600');
    if (!printWindow) {
      toast.error('Pop-up blocked. Please allow pop-ups to print test receipt.');
      return;
    }
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const formattedDate = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}`;
    const formattedTime = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;

    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Test Printing - ${printerName || 'POS'}</title>
          <style>
            @page { size: auto; margin: 0; }
            body {
              font-family: 'Courier New', Courier, monospace;
              font-size: ${is58 ? '11px' : '12.5px'};
              width: ${rollWidth};
              margin: 0 auto;
              padding: 12px 10px;
              color: #000;
              background: #fff;
              line-height: 1.35;
            }
            .center { text-align: center; }
            .bold { font-weight: bold; }
            .title { font-size: ${is58 ? '18px' : '22px'}; font-weight: 900; margin: 8px 0; letter-spacing: 0.5px; }
            .store { font-size: 14px; font-weight: bold; margin-bottom: 4px; }
            .divider { border-bottom: 1px dashed #000; margin: 6px 0; }
            .solid-divider { border-bottom: 1px solid #000; margin: 6px 0; }
            .row { display: flex; justify-content: space-between; margin: 3px 0; }
            .footer { margin-top: 10px; font-size: 11px; text-align: center; }
          </style>
        </head>
        <body>
          <div class="center store">${businessName || 'IQ Restaurant POS'}</div>
          ${addrLine1 ? `<div class="center">${addrLine1}</div>` : ''}
          ${phoneNumber ? `<div class="center">Tel: ${phoneNumber}</div>` : ''}
          <div class="divider"></div>
          <div class="center bold title">Test Printing</div>
          <div class="divider"></div>
          <div class="row"><span>Date:</span><span>${formattedDate}</span></div>
          <div class="row"><span>Time:</span><span>${formattedTime}</span></div>
          <div class="solid-divider"></div>
          <div class="row"><span>Printer:</span><span>${printerName || 'Main Counter LAN Printer'}</span></div>
          <div class="row"><span>IP Address:</span><span>${ipAddress}:${port}</span></div>
          <div class="row"><span>Roll Size:</span><span>${is58 ? '58mm Roll (32 col)' : '80mm Roll (48 col)'}</span></div>
          <div class="row"><span>Status:</span><span>ONLINE / OK</span></div>
          <div class="divider"></div>
          <div class="center bold" style="margin: 8px 0;">*** TEST PRINT COMPLETED ***</div>
          <div class="center footer">Powered by IQ POS</div>
          <script>
            window.onload = function() {
              window.print();
              setTimeout(function() { window.close(); }, 1200);
            };
          </script>
        </body>
      </html>
    `);
    printWindow.document.close();
  };

  return (
    <div className="printer-settings-container">
      {/* 1. Header Bar */}
      <div className="printer-header">
        <div className="printer-header-left">
          <div className="printer-header-icon-box">
            <Printer size={26} />
          </div>
          <div>
            <h1 className="printer-header-title">Printer Settings</h1>
            <p className="printer-header-subtitle">
              Configure LAN thermal receipt printers, roll sizing and ESC/POS templates
            </p>
          </div>
        </div>

        <div className="printer-header-actions">
          <button
            type="button"
            className="printer-btn printer-btn--secondary"
            onClick={handleTestPrint}
            disabled={isTesting || isLoading}
            title="Send 'Test Printing' command to LAN printer"
          >
            {isTesting ? <RefreshCw size={16} className="spin" /> : <Printer size={16} />}
            <span>{isTesting ? 'Printing...' : 'Test Print'}</span>
          </button>

          <button
            type="button"
            className="printer-btn printer-btn--primary"
            onClick={handleSaveSettings}
            disabled={isSaving || isLoading}
          >
            {isSaving ? <RefreshCw size={16} className="spin" /> : <Save size={16} />}
            <span>{isSaving ? 'Saving...' : 'Save Settings'}</span>
          </button>
        </div>
      </div>

      {/* 2. Status Banner */}
      <div className="printer-status-banner">
        <div className="printer-status-banner__left">
          <span
            className={`printer-status-dot ${!isEnabled ? 'printer-status-dot--offline' : ''}`}
          />
          <div>
            <div className="printer-status-banner__title">
              {printerName} • {connectionType === 'lan' ? `${ipAddress}:${port}` : 'USB Spooler'}
            </div>
            <div className="printer-status-banner__meta">
              {isEnabled
                ? 'Device is active and ready for receipt jobs'
                : 'Device is toggled off (receipts will not be dispatched)'}
            </div>
          </div>
        </div>

        <div className="printer-status-badges">
          <span className="printer-badge printer-badge--lan">
            <Wifi size={12} />
            <span>LAN TCP/IP</span>
          </span>
          <span className="printer-badge printer-badge--paper">
            <span>{paperSize === 'mm80' ? '80mm Roll (48c)' : '58mm Roll (32c)'}</span>
          </span>
          {isDefault && (
            <span className="printer-badge printer-badge--default">
              <Check size={12} />
              <span>Default</span>
            </span>
          )}
        </div>
      </div>

      {/* Test Alert Banner (if tested) */}
      {testResult.status && (
        <div className={`printer-test-alert printer-test-alert--${testResult.status}`}>
          <div className="printer-test-alert__content">
            {testResult.status === 'success' ? (
              <CheckCircle2 size={18} />
            ) : testResult.status === 'error' ? (
              <AlertCircle size={18} />
            ) : (
              <RefreshCw size={18} className="spin" />
            )}
            <span>{testResult.message}</span>
          </div>
          <div className="printer-test-alert__actions">
            <button
              type="button"
              className="printer-alert-action-btn"
              onClick={handleTestPrint}
              disabled={isTesting}
            >
              <Printer size={13} />
              <span>{isTesting ? 'Printing...' : 'Retry LAN Print'}</span>
            </button>
            <button
              type="button"
              className="printer-alert-action-btn printer-alert-action-btn--alt"
              onClick={handleBrowserTestPrint}
            >
              <FileText size={13} />
              <span>Print via System</span>
            </button>
          </div>
        </div>
      )}

      {/* 3. Main Two-Column Layout */}
      <div className="printer-layout-grid">
        {/* Left Column: Form Settings Cards */}
        <div className="printer-form-column">
          {/* Card 1: Printer Profile & Connection */}
          <div className="printer-card">
            <div className="printer-card__header">
              <div
                className="printer-card__icon"
                style={{ background: '#EFF6FF', color: '#2563EB' }}
              >
                <Printer size={18} />
              </div>
              <div>
                <h3 className="printer-card__title">Printer Profile & Identity</h3>
                <p className="printer-card__sub">
                  Label your device and choose connection interface
                </p>
              </div>
            </div>

            <div className="printer-grid-2 printer-form-group">
              <div>
                <label className="printer-label">Printer Display Name</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="e.g. Counter LAN Thermal Printer"
                  value={printerName}
                  onChange={(e) => setPrinterName(e.target.value)}
                />
              </div>

              <div>
                <label className="printer-label">Connection Type</label>
                <select
                  className="printer-input"
                  value={connectionType}
                  onChange={(e) => setConnectionType(e.target.value as 'lan' | 'usb')}
                >
                  <option value="lan">LAN / Network Thermal (TCP/IP)</option>
                  <option value="usb">USB / OS Installed Spooler</option>
                </select>
              </div>
            </div>

            <div className="printer-grid-2">
              <div className="printer-toggle-row">
                <div className="printer-toggle-info">
                  <span className="printer-toggle-title">Device Enabled</span>
                  <span className="printer-toggle-sub">Power switch for this printer</span>
                </div>
                <label className="printer-switch">
                  <input
                    type="checkbox"
                    checked={isEnabled}
                    onChange={(e) => setIsEnabled(e.target.checked)}
                  />
                  <span className="printer-slider" />
                </label>
              </div>

              <div className="printer-toggle-row">
                <div className="printer-toggle-info">
                  <span className="printer-toggle-title">Default POS Printer</span>
                  <span className="printer-toggle-sub">Primary station destination</span>
                </div>
                <label className="printer-switch">
                  <input
                    type="checkbox"
                    checked={isDefault}
                    onChange={(e) => setIsDefault(e.target.checked)}
                  />
                  <span className="printer-slider" />
                </label>
              </div>
            </div>
          </div>

          {/* Card 2: LAN Network Configuration */}
          <div className="printer-card">
            <div className="printer-card__header">
              <div
                className="printer-card__icon"
                style={{ background: '#ECFDF5', color: '#059669' }}
              >
                <Wifi size={18} />
              </div>
              <div>
                <h3 className="printer-card__title">LAN Printer Network Address</h3>
                <p className="printer-card__sub">
                  Target raw socket parameters for network thermal printer
                </p>
              </div>
            </div>

            <div className="printer-grid-2 printer-form-group">
              <div>
                <label className="printer-label">
                  <span>LAN Printer IP Address</span>
                  <span className="printer-label__hint">IPv4</span>
                </label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="e.g. 192.168.1.100"
                  value={ipAddress}
                  onChange={(e) => setIpAddress(e.target.value)}
                />
              </div>

              <div>
                <label className="printer-label">
                  <span>Port Number</span>
                  <span className="printer-label__hint">Default 9100</span>
                </label>
                <input
                  type="number"
                  className="printer-input"
                  placeholder="9100"
                  value={port}
                  onChange={(e) => setPort(parseInt(e.target.value, 10) || 9100)}
                />
              </div>
            </div>

            <p style={{ fontSize: '11.5px', color: '#64748B', margin: '4px 0 0' }}>
              💡 Ensure the LAN thermal printer is assigned a static IP or DHCP reservation on your
              local router so communication remains stable.
            </p>
          </div>

          {/* Card 3: Roll Sizing & ESC/POS Commands */}
          <div className="printer-card">
            <div className="printer-card__header">
              <div
                className="printer-card__icon"
                style={{ background: '#FAF5FF', color: '#9333EA' }}
              >
                <Layers size={18} />
              </div>
              <div>
                <h3 className="printer-card__title">Paper Roll Specifications</h3>
                <p className="printer-card__sub">
                  Select thermal paper width to calibrate character columns
                </p>
              </div>
            </div>

            <div className="printer-radio-cards printer-form-group">
              <div
                className={`printer-radio-card ${
                  paperSize === 'mm80' ? 'printer-radio-card--selected' : ''
                }`}
                onClick={() => setPaperSize('mm80')}
              >
                <div className="printer-radio-card__top">
                  <span className="printer-radio-card__name">80mm Thermal Roll</span>
                  <Radio size={16} color={paperSize === 'mm80' ? '#2563EB' : '#94A3B8'} />
                </div>
                <p className="printer-radio-card__desc">
                  Standard 48 columns per line. Ideal for detailed item names, tax breakdowns, and
                  service receipts.
                </p>
              </div>

              <div
                className={`printer-radio-card ${
                  paperSize === 'mm58' ? 'printer-radio-card--selected' : ''
                }`}
                onClick={() => setPaperSize('mm58')}
              >
                <div className="printer-radio-card__top">
                  <span className="printer-radio-card__name">58mm Compact Roll</span>
                  <Radio size={16} color={paperSize === 'mm58' ? '#2563EB' : '#94A3B8'} />
                </div>
                <p className="printer-radio-card__desc">
                  Compact 32 columns per line. Suitable for portable thermal printers and kiosk
                  vouchers.
                </p>
              </div>
            </div>

            <div className="printer-grid-2">
              <div className="printer-toggle-row">
                <div className="printer-toggle-info">
                  <span className="printer-toggle-title">Auto-Cut Paper</span>
                  <span className="printer-toggle-sub">Send GS V command after ticket</span>
                </div>
                <label className="printer-switch">
                  <input
                    type="checkbox"
                    checked={autoCut}
                    onChange={(e) => setAutoCut(e.target.checked)}
                  />
                  <span className="printer-slider" />
                </label>
              </div>

              <div className="printer-toggle-row">
                <div className="printer-toggle-info">
                  <span className="printer-toggle-title">Cash Drawer Kick</span>
                  <span className="printer-toggle-sub">Send ESC p pulse on cash checkout</span>
                </div>
                <label className="printer-switch">
                  <input
                    type="checkbox"
                    checked={openCashDrawer}
                    onChange={(e) => setOpenCashDrawer(e.target.checked)}
                  />
                  <span className="printer-slider" />
                </label>
              </div>
            </div>
          </div>

          {/* Card 4: Store Branding & Receipt Header/Footer */}
          <div className="printer-card">
            <div className="printer-card__header">
              <div
                className="printer-card__icon"
                style={{ background: '#FFF7ED', color: '#EA580C' }}
              >
                <Store size={18} />
              </div>
              <div>
                <h3 className="printer-card__title">Receipt Branding & Contact Header</h3>
                <p className="printer-card__sub">
                  Store details displayed at the top and bottom of each printout
                </p>
              </div>
            </div>

            <div className="printer-grid-2 printer-form-group">
              <div>
                <label className="printer-label">Business Name</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="e.g. IQ Store"
                  value={businessName}
                  onChange={(e) => setBusinessName(e.target.value)}
                />
              </div>

              <div>
                <label className="printer-label">Store Phone</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="e.g. +1 (555) 019-2834"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value)}
                />
              </div>
            </div>

            <div className="printer-grid-2 printer-form-group">
              <div>
                <label className="printer-label">Address Line 1</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="100 Terminal Boulevard"
                  value={addrLine1}
                  onChange={(e) => setAddrLine1(e.target.value)}
                />
              </div>
              <div>
                <label className="printer-label">Address Line 2</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="Suite 400"
                  value={addrLine2}
                  onChange={(e) => setAddrLine2(e.target.value)}
                />
              </div>
            </div>

            <div className="printer-grid-2 printer-form-group">
              <div>
                <label className="printer-label">Address Line 3 (City/State)</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="New York, NY 10001"
                  value={addrLine3}
                  onChange={(e) => setAddrLine3(e.target.value)}
                />
              </div>
              <div>
                <label className="printer-label">Address Line 4 (Tax ID)</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="Tax ID: US-987654321"
                  value={addrLine4}
                  onChange={(e) => setAddrLine4(e.target.value)}
                />
              </div>
            </div>

            <div className="printer-grid-2">
              <div>
                <label className="printer-label">Receipt Header Subtitle</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="Tax Invoice / Official Receipt"
                  value={headerNote}
                  onChange={(e) => setHeaderNote(e.target.value)}
                />
              </div>
              <div>
                <label className="printer-label">Footer Thank-You Message</label>
                <input
                  type="text"
                  className="printer-input"
                  placeholder="Thank you for your visit! Please come again."
                  value={footerNote}
                  onChange={(e) => setFooterNote(e.target.value)}
                />
              </div>
            </div>
          </div>

          {/* Card 5: Receipt Routing Automation (from printers_screen.dart) */}
          <div className="printer-card">
            <div className="printer-card__header">
              <div
                className="printer-card__icon"
                style={{ background: '#FEF2F2', color: '#DC2626' }}
              >
                <FileText size={18} />
              </div>
              <div>
                <h3 className="printer-card__title">Receipt Routing & Job Rules</h3>
                <p className="printer-card__sub">
                  Control which documents automatically dispatch to this printer
                </p>
              </div>
            </div>

            <div className="printer-toggle-row">
              <div className="printer-toggle-info">
                <span className="printer-toggle-title">Print Customer Sales Receipts</span>
                <span className="printer-toggle-sub">
                  Dispatches tax receipts upon order payment checkout
                </span>
              </div>
              <label className="printer-switch">
                <input
                  type="checkbox"
                  checked={orderReceiptEnabled}
                  onChange={(e) => setOrderReceiptEnabled(e.target.checked)}
                />
                <span className="printer-slider" />
              </label>
            </div>
          </div>
        </div>

        {/* Right Column: Live Thermal Receipt Preview */}
        <div className="printer-preview-column">
          <div className="printer-preview-card">
            <div className="printer-preview-header">
              <div className="printer-preview-title">
                <FileText size={16} />
                <span>Thermal Preview</span>
              </div>
              <div className="printer-preview-tabs">
                <button
                  type="button"
                  className={`printer-preview-tab-btn ${
                    previewTab === 'customer' ? 'printer-preview-tab-btn--active' : ''
                  }`}
                  onClick={() => setPreviewTab('customer')}
                >
                  Receipt
                </button>
                <button
                  type="button"
                  className={`printer-preview-tab-btn ${
                    previewTab === 'test' ? 'printer-preview-tab-btn--active' : ''
                  }`}
                  onClick={() => setPreviewTab('test')}
                >
                  Test Print
                </button>
              </div>
            </div>

            {/* Thermal Paper Visual */}
            <div className="thermal-paper-container">
              <div
                className={`thermal-paper ${
                  paperSize === 'mm80' ? 'thermal-paper--80mm' : 'thermal-paper--58mm'
                }`}
              >
                <div className="thermal-paper__center">
                  <div className="thermal-paper__store-name">{businessName || 'IQ STORE'}</div>
                  {addrLine1 && <div className="thermal-paper__meta">{addrLine1}</div>}
                  {addrLine2 && <div className="thermal-paper__meta">{addrLine2}</div>}
                  {addrLine3 && <div className="thermal-paper__meta">{addrLine3}</div>}
                  {phoneNumber && <div className="thermal-paper__meta">Tel: {phoneNumber}</div>}
                  {addrLine4 && <div className="thermal-paper__meta">{addrLine4}</div>}
                  {headerNote && (
                    <div
                      className="thermal-paper__meta"
                      style={{ marginTop: 4, fontWeight: 700 }}
                    >
                      {headerNote}
                    </div>
                  )}
                </div>

                <div className="thermal-paper__divider" />

                {previewTab === 'customer' ? (
                  <>
                    <div className="thermal-paper__row">
                      <span>Receipt: #REC-9824</span>
                      <span>{new Date().toLocaleDateString()}</span>
                    </div>
                    <div className="thermal-paper__row">
                      <span>Cashier: Station 1</span>
                      <span>
                        {new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>

                    <div className="thermal-paper__solid-divider" />

                    <div className="thermal-paper__row thermal-paper__bold">
                      <span>ITEM</span>
                      <span>TOTAL</span>
                    </div>
                    <div className="thermal-paper__divider" />

                    <div className="thermal-paper__row">
                      <span>Haircut & Beard Trim</span>
                      <span>$45.00</span>
                    </div>
                    <div
                      className="thermal-paper__row"
                      style={{ fontSize: paperSize === 'mm80' ? '10px' : '9px', color: '#64748B' }}
                    >
                      <span>1 × $45.00</span>
                    </div>

                    <div className="thermal-paper__row">
                      <span>Organic Shampoo (250ml)</span>
                      <span>$18.00</span>
                    </div>
                    <div
                      className="thermal-paper__row"
                      style={{ fontSize: paperSize === 'mm80' ? '10px' : '9px', color: '#64748B' }}
                    >
                      <span>1 × $18.00</span>
                    </div>

                    <div className="thermal-paper__divider" />

                    <div className="thermal-paper__row">
                      <span>Subtotal</span>
                      <span>$63.00</span>
                    </div>
                    <div className="thermal-paper__row">
                      <span>Tax (8%)</span>
                      <span>$5.04</span>
                    </div>
                    <div className="thermal-paper__solid-divider" />

                    <div
                      className="thermal-paper__row thermal-paper__bold"
                      style={{ fontSize: paperSize === 'mm80' ? '12.5px' : '11px' }}
                    >
                      <span>TOTAL PAID</span>
                      <span>$68.04</span>
                    </div>

                    <div className="thermal-paper__divider" />
                    <div className="thermal-paper__row">
                      <span>Payment: CASH</span>
                      <span>Tendered: $70.00</span>
                    </div>
                    <div className="thermal-paper__row">
                      <span>Change Due</span>
                      <span>$1.96</span>
                    </div>
                  </>
                ) : (
                  <>
                    <div
                      className="thermal-paper__center thermal-paper__bold"
                      style={{
                        fontSize: paperSize === 'mm80' ? '18px' : '15px',
                        margin: '6px 0',
                        letterSpacing: '0.5px',
                      }}
                    >
                      Test Printing
                    </div>
                    <div className="thermal-paper__divider" />
                    <div className="thermal-paper__row">
                      <span>Date:</span>
                      <span>{new Date().toLocaleDateString()}</span>
                    </div>
                    <div className="thermal-paper__row">
                      <span>Time:</span>
                      <span>
                        {new Date().toLocaleTimeString([], {
                          hour: '2-digit',
                          minute: '2-digit',
                          second: '2-digit',
                        })}
                      </span>
                    </div>
                    <div className="thermal-paper__solid-divider" />
                    <div className="thermal-paper__row">
                      <span>Printer:</span>
                      <span style={{ fontWeight: 600 }}>{printerName}</span>
                    </div>
                    <div className="thermal-paper__row">
                      <span>IP Address:</span>
                      <span>
                        {ipAddress}:{port}
                      </span>
                    </div>
                    <div className="thermal-paper__row">
                      <span>Roll Size:</span>
                      <span>{paperSize === 'mm80' ? '80mm Roll (48c)' : '58mm Roll (32c)'}</span>
                    </div>
                    <div className="thermal-paper__row">
                      <span>Status:</span>
                      <span style={{ color: '#059669', fontWeight: 600 }}>READY / OK</span>
                    </div>
                    <div className="thermal-paper__solid-divider" />
                    <div
                      className="thermal-paper__center thermal-paper__bold"
                      style={{ margin: '8px 0', fontSize: '11px' }}
                    >
                      *** TEST PRINT COMPLETED ***
                    </div>
                    <div
                      className="thermal-paper__center"
                      style={{ fontSize: '10px', color: '#64748B' }}
                    >
                      Powered by IQ POS
                    </div>
                  </>
                )}

                <div className="thermal-paper__divider" />
                <div className="thermal-paper__barcode-mock" />

                {footerNote && <div className="thermal-paper__footer">{footerNote}</div>}
              </div>
            </div>

            {/* Bottom Preview Actions */}
            <div className="printer-preview-bottom-actions">
              <button
                type="button"
                className="printer-btn printer-btn--secondary"
                style={{ flex: 1 }}
                onClick={handleTestPrint}
                disabled={isTesting}
                title="Send 'Test Printing' to LAN printer"
              >
                {isTesting ? <RefreshCw size={15} className="spin" /> : <Printer size={15} />}
                <span>{isTesting ? 'Printing...' : 'Print "Test Printing" (LAN)'}</span>
              </button>
              <button
                type="button"
                className="printer-btn printer-btn--secondary"
                style={{ flex: 1 }}
                onClick={handleBrowserTestPrint}
                title="Open system print dialog with 'Test Printing' slip"
              >
                <FileText size={15} />
                <span>System Print</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
