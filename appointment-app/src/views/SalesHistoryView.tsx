import { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-toastify';
import {
  Receipt,
  RotateCw,
  RotateCcw,
  Banknote,
  Search,
  X,
  ChevronRight,
  ChevronLeft,
  ChevronDown,
  User,
  BadgeCheck,
  Clock,
  CalendarCheck,
  Printer,
} from 'lucide-react';
import { saleApi, type Sale, type SaleSummary, formatReceiptNumber, getPaymentMethodLabel } from '../api/saleApi';
import { useAppSelector } from '../store/hooks';
import { executeReceiptPrint } from '../utils/receiptPrinter';
import RefundModal from '../components/RefundModal';
import DateRangeFilter from '../components/DateRangeFilter';
import '../styles/sales_history.css';
import '../styles/refund_modal.css';
import '../styles/date_range_filter.css';

const PAGE_SIZE = 20;

/* ── Safe Currency / Number Formatter ─────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

export default function SalesHistoryView() {
  /* ── Default Date Range: Today ─────────────────────────── */
  const todayStr = (() => {
    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  })();

  const [startDate, setStartDate] = useState<string>(todayStr);
  const [endDate, setEndDate] = useState<string>(todayStr);

  /* ── State ────────────────────────────────────────────── */
  const [allSales, setAllSales] = useState<Sale[]>([]);
  const [totalCount, setTotalCount] = useState<number>(0);
  const [totalPages, setTotalPages] = useState<number>(1);
  const [summary, setSummary] = useState<SaleSummary>({
    total: 0,
    completed: 0,
    total_revenue: 0,
  });

  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSearching, setIsSearching] = useState<boolean>(false);

  const [searchInput, setSearchInput] = useState<string>('');
  const [activeSearchQuery, setActiveSearchQuery] = useState<string>('');
  const [activeFilter, setActiveFilter] = useState<'all' | 'cash' | 'card' | 'qr'>('all');
  const [isPanelExpanded, setIsPanelExpanded] = useState<boolean>(true);

  const [currentPage, setCurrentPage] = useState<number>(1);
  const [detailSale, setDetailSale] = useState<Sale | null>(null);
  const [showRefundModal, setShowRefundModal] = useState<boolean>(false);

  const printerSettings = useAppSelector((state) => state.printer.settings);
  const [printingSaleId, setPrintingSaleId] = useState<number | null>(null);

  /* ── Print / Reprint Handler ───────────────────────────── */
  const handlePrintSale = async (saleToPrint: Sale, e?: React.MouseEvent) => {
    if (e) {
      e.stopPropagation();
    }
    setPrintingSaleId(saleToPrint.id);
    try {
      let fullSale = { ...saleToPrint };
      if (!fullSale.refunds || fullSale.refunds.length === 0) {
        try {
          const rfRes = await saleApi.getRefunds(saleToPrint.id);
          if (rfRes.data?.data && Array.isArray(rfRes.data.data)) {
            fullSale.refunds = rfRes.data.data;
          }
        } catch (_) {}
      }
      const sRefunds = fullSale.refunds || [];
      const totalGstRefunded =
        fullSale.gst_reversed_total !== undefined
          ? Number(fullSale.gst_reversed_total)
          : sRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.gst_reversed_total) || 0), 0);
      const totalSubtotalRefunded =
        fullSale.subtotal_refunded_total !== undefined
          ? Number(fullSale.subtotal_refunded_total)
          : sRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.subtotal_refunded) || 0), 0);
      fullSale.gst_reversed_total = totalGstRefunded;
      fullSale.net_tax_amount = Math.max(0, Math.round(((Number(fullSale.tax_amount) || 0) - totalGstRefunded) * 100) / 100);
      fullSale.subtotal_refunded_total = totalSubtotalRefunded;
      fullSale.net_subtotal = Math.max(0, Math.round(((Number(fullSale.subtotal) || 0) - totalSubtotalRefunded) * 100) / 100);

      await executeReceiptPrint({
        printerSettings,
        transaction: fullSale,
        type: 'sale',
        isReprint: true,
      });
    } catch (err: any) {
      console.error('Print sale error:', err);
      toast.error('Failed to trigger receipt printing.');
    } finally {
      setPrintingSaleId(null);
    }
  };

  /* ── Helper to Normalize API Sales ────────────────────── */
  const normalizeSalesList = (rawList: any[]): Sale[] => {
    // Strictly normal POS/Cart transactions only (appointment_id must be null or 0)
    const posSales = rawList.filter((s) => !s.appointment_id || s.appointment_id === 0);
    return posSales.map((s) => {
      let parsedItems: any[] = [];
      if (s.items) {
        if (Array.isArray(s.items)) {
          parsedItems = s.items;
        } else if (typeof s.items === 'string') {
          try {
            parsedItems = JSON.parse(s.items);
          } catch {
            parsedItems = [];
          }
        }
      }

      const origTax = Number(s.tax_amount) || 0;
      const origSubtotal = Number(s.subtotal) || 0;
      const sRefunds = s.refunds || [];
      const totalGstRefunded =
        s.gst_reversed_total !== undefined
          ? Number(s.gst_reversed_total)
          : sRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.gst_reversed_total) || 0), 0);
      const totalSubtotalRefunded =
        s.subtotal_refunded_total !== undefined
          ? Number(s.subtotal_refunded_total)
          : sRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.subtotal_refunded) || 0), 0);
      const netTax =
        s.net_tax_amount !== undefined
          ? Number(s.net_tax_amount)
          : Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100);
      const netSubtotal =
        s.net_subtotal !== undefined
          ? Number(s.net_subtotal)
          : Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100);

      return {
        ...s,
        subtotal: origSubtotal,
        item_discount_total: Number(s.item_discount_total) || 0,
        overall_discount: Number(s.overall_discount) || 0,
        tax_amount: origTax,
        total_amount: Number(s.total_amount) || 0,
        amount_tendered: Number(s.amount_tendered) || 0,
        change_amount: Number(s.change_amount) || 0,
        refund_status: s.refund_status || (Number(s.refunded_amount) > 0 ? (Number(s.refunded_amount) >= Number(s.total_amount) ? 'full' : 'partial') : 'none'),
        refunded_amount: Number(s.refunded_amount) || 0,
        refunds: sRefunds,
        gst_reversed_total: totalGstRefunded,
        net_tax_amount: netTax,
        subtotal_refunded_total: totalSubtotalRefunded,
        net_subtotal: netSubtotal,
        items: parsedItems.map((it) => ({
          product_id: it.product_id,
          product_name: it.product_name || it.name || 'Item',
          unit_price: Number(it.unit_price) || 0,
          quantity: Number(it.quantity) || 1,
          discount: Number(it.discount) || 0,
          line_total: Number(it.line_total) || ((Number(it.unit_price) || 0) * (Number(it.quantity) || 1)),
        })),
      };
    });
  };

  const handleRefundSuccess = (updatedSale: Sale) => {
    setDetailSale(updatedSale);
    setAllSales((prev) =>
      prev.map((s) => (s.id === updatedSale.id ? updatedSale : s))
    );
    fetchSummary(startDate, endDate, activeSearchQuery, activeFilter);
  };

  /* ── 1. Fetch Summary API ─────────────────────────────── */
  const fetchSummary = useCallback(
    async (start: string, end: string, query?: string, method?: string) => {
      try {
        const res = await saleApi.getSummary({
          start_date: start,
          end_date: end,
          search: query || undefined,
          payment_method: method && method !== 'all' ? method : undefined,
        });
        if (res.data?.data) {
          setSummary(res.data.data);
        }
      } catch (err) {
        console.error('Error fetching sales summary:', err);
      }
    },
    []
  );

  /* ── 2. Fetch History Data API (Backend Paginated) ─────── */
  const fetchSales = useCallback(
    async (pageToLoad: number, start: string, end: string, query?: string, method?: string) => {
      setIsLoading(true);
      try {
        const res = await saleApi.getAll({
          start_date: start,
          end_date: end,
          search: query || undefined,
          payment_method: method && method !== 'all' ? method : undefined,
          page: pageToLoad,
          limit: PAGE_SIZE,
        });
        const rawList = res.data?.data ?? [];
        const list = normalizeSalesList(rawList);
        setAllSales(list);
        const total = res.data?.total ?? list.length;
        setTotalCount(total);
        setTotalPages(res.data?.totalPages ?? Math.max(1, Math.ceil(total / PAGE_SIZE)));
        setCurrentPage(pageToLoad);
      } catch (err) {
        console.error('Error loading sales:', err);
        toast.error('Failed to load sales history');
      } finally {
        setIsLoading(false);
      }
    },
    []
  );

  /* ── Initial Load: Today's Date Filter ─────────────────── */
  useEffect(() => {
    fetchSales(1, todayStr, todayStr, undefined, 'all');
    fetchSummary(todayStr, todayStr, undefined, 'all');
  }, [fetchSales, fetchSummary, todayStr]);

  /* ── Date Range Change Handler ────────────────────────── */
  const handleDateRangeChange = (newStart: string, newEnd: string) => {
    setStartDate(newStart);
    setEndDate(newEnd);
    fetchSales(1, newStart, newEnd, activeSearchQuery, activeFilter);
    fetchSummary(newStart, newEnd, activeSearchQuery, activeFilter);
  };

  /* ── Page Change Handler (Loads only current page records) */
  const handlePageChange = (newPage: number) => {
    if (newPage < 1 || newPage > totalPages || newPage === currentPage) return;
    fetchSales(newPage, startDate, endDate, activeSearchQuery, activeFilter);
  };

  /* ── Payment Method Filter Change Handler ─────────────── */
  const handleFilterChange = (filter: 'all' | 'cash' | 'card' | 'qr') => {
    setActiveFilter(filter);
    fetchSales(1, startDate, endDate, activeSearchQuery, filter);
    fetchSummary(startDate, endDate, activeSearchQuery, filter);
  };

  /* ── Search Handlers ──────────────────────────────────── */
  const handlePerformSearch = async () => {
    const query = searchInput.trim();
    setIsSearching(true);
    setActiveSearchQuery(query);
    try {
      await Promise.all([
        fetchSales(1, startDate, endDate, query.length > 0 ? query : undefined, activeFilter),
        fetchSummary(startDate, endDate, query.length > 0 ? query : undefined, activeFilter),
      ]);
    } finally {
      setIsSearching(false);
    }
  };

  const handleResetSearch = () => {
    setSearchInput('');
    setActiveSearchQuery('');
    fetchSales(1, startDate, endDate, undefined, activeFilter);
    fetchSummary(startDate, endDate, undefined, activeFilter);
  };

  /* ── Reload Handler ───────────────────────────────────── */
  const handleRefresh = () => {
    fetchSales(currentPage, startDate, endDate, activeSearchQuery, activeFilter);
    fetchSummary(startDate, endDate, activeSearchQuery, activeFilter);
  };

  /* ── Pagination Bounds ────────────────────────────────── */
  const startItem = totalCount === 0 ? 0 : (currentPage - 1) * PAGE_SIZE + 1;
  const endItem = Math.min(currentPage * PAGE_SIZE, totalCount);

  /* ── Date/Time Formatter ──────────────────────────────── */
  const formatDateTime = (dateStr?: string) => {
    if (!dateStr) return 'N/A';
    const dt = new Date(dateStr);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const h = dt.getHours();
    const hour = h % 12 === 0 ? 12 : h % 12;
    const ampm = h >= 12 ? 'PM' : 'AM';
    const min = String(dt.getMinutes()).padStart(2, '0');
    return `${dt.getDate()} ${months[dt.getMonth()]} ${dt.getFullYear()}, ${hour}:${min} ${ampm}`;
  };

  /* ── Render ───────────────────────────────────────────── */
  return (
    <div className="sales-history-container">
      {/* ── Main Collapsible Card Container ────────────────── */}
      <div className="sales-main-card">
        {/* Main Header (Always Visible) */}
        <div
          className={`sales-main-card__header ${isPanelExpanded ? 'sales-main-card__header--expanded' : ''}`}
          onClick={() => setIsPanelExpanded((prev) => !prev)}
        >
          <div className="sales-main-card__header-left">
            <h2 className="sales-main-card__title">Sales History &amp; POS Orders</h2>
            <span className="sales-main-card__badge">{summary.completed} Orders</span>
          </div>

          <div className="sales-main-card__header-right">
            <button
              type="button"
              className="sales-refresh-btn"
              disabled={isLoading}
              onClick={(e) => {
                e.stopPropagation();
                handleRefresh();
              }}
              title="Refresh sales history"
            >
              <RotateCw
                size={15}
                color="#E11D48"
                className={isLoading ? 'table-loader-spinner' : ''}
              />
              <span>Refresh</span>
            </button>

            {/* Dropdown / Expand-Collapse Button */}
            <button
              type="button"
              className={`sales-toggle-btn ${!isPanelExpanded ? 'sales-toggle-btn--collapsed' : ''}`}
              onClick={(e) => {
                e.stopPropagation();
                setIsPanelExpanded((prev) => !prev);
              }}
              title={isPanelExpanded ? 'Collapse metrics and search' : 'Expand metrics and search'}
              aria-label={isPanelExpanded ? 'Collapse section' : 'Expand section'}
            >
              <ChevronDown size={18} />
            </button>
          </div>
        </div>

        {/* Collapsible Content: 3 KPI Cards + Filter Bar & Search */}
        <div className={`sales-main-card__collapsible ${!isPanelExpanded ? 'sales-main-card__collapsible--collapsed' : ''}`}>
          <div className="sales-main-card__collapsible-inner">
            {/* 2. Compact KPI Metrics Row from Summary API */}
            <div className="sales-metrics-row">
              {/* Total Completed Orders */}
              <div className="sales-metric-card">
                <div className="sales-metric-icon" style={{ background: '#EEF2FF', color: '#4F46E5' }}>
                  <Receipt size={18} />
                </div>
                <div className="sales-metric-info">
                  <div className="sales-metric-title">Completed Orders</div>
                  <div className="sales-metric-value">{summary.completed} Orders</div>
                  <div className="sales-metric-sub">100% fulfilled POS sales</div>
                </div>
              </div>

              {/* Total Orders */}
              <div className="sales-metric-card">
                <div className="sales-metric-icon" style={{ background: '#F0F9FF', color: '#0EA5E9' }}>
                  <CalendarCheck size={18} />
                </div>
                <div className="sales-metric-info">
                  <div className="sales-metric-title">Total Orders</div>
                  <div className="sales-metric-value">{summary.total} Orders</div>
                  <div className="sales-metric-sub">In selected date range</div>
                </div>
              </div>

              {/* Register Revenue */}
              <div className="sales-metric-card">
                <div className="sales-metric-icon" style={{ background: '#ECFDF5', color: '#059669' }}>
                  <Banknote size={18} />
                </div>
                <div className="sales-metric-info">
                  <div className="sales-metric-title">Register Revenue</div>
                  <div className="sales-metric-value">${fmtMoney(summary.total_revenue)}</div>
                  <div className="sales-metric-sub">Total earned tender in range</div>
                </div>
              </div>
            </div>

            {/* 3. Filter Bar & Search */}
            <div className="sales-filter-bar">
              {/* Modern Date Range Filter Popup */}
              <DateRangeFilter
                startDate={startDate}
                endDate={endDate}
                onChange={handleDateRangeChange}
                className="sales-date-range-filter"
              />

              <div className="sales-filter-chips">
                <button
                  type="button"
                  className={`sales-filter-chip ${activeFilter === 'all' ? 'sales-filter-chip--active-all' : ''}`}
                  onClick={() => handleFilterChange('all')}
                >
                  All Sales
                </button>
                <button
                  type="button"
                  className={`sales-filter-chip ${activeFilter === 'cash' ? 'sales-filter-chip--active-cash' : ''}`}
                  onClick={() => handleFilterChange('cash')}
                >
                  Cash
                </button>
                <button
                  type="button"
                  className={`sales-filter-chip ${activeFilter === 'card' ? 'sales-filter-chip--active-card' : ''}`}
                  onClick={() => handleFilterChange('card')}
                >
                  Card
                </button>
                <button
                  type="button"
                  className={`sales-filter-chip ${activeFilter === 'qr' ? 'sales-filter-chip--active-qr' : ''}`}
                  onClick={() => handleFilterChange('qr')}
                >
                  QR Payment
                </button>
              </div>

              {/* Search */}
              <div className="sales-search-section">
                <div className="sales-search-box">
                  <Search size={15} className="sales-search-box__icon" />
                  <input
                    type="text"
                    className="sales-search-input"
                    placeholder="Search customer, phone, staff..."
                    value={searchInput}
                    onChange={(e) => setSearchInput(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handlePerformSearch()}
                  />
                  {searchInput && (
                    <button
                      type="button"
                      className="sales-search-clear-btn"
                      onClick={() => {
                        setSearchInput('');
                        if (activeSearchQuery) handleResetSearch();
                      }}
                    >
                      <X size={13} />
                    </button>
                  )}
                </div>

                <button
                  type="button"
                  className="sales-search-apply-btn"
                  disabled={isSearching}
                  onClick={handlePerformSearch}
                >
                  {isSearching ? (
                    <span className="table-loader-spinner" style={{ width: '13px', height: '13px', borderColor: '#fff', borderTopColor: 'transparent' }} />
                  ) : (
                    <>
                      <Search size={13} />
                      <span>Apply</span>
                    </>
                  )}
                </button>

                {(activeSearchQuery || activeFilter !== 'all') && (
                  <button
                    type="button"
                    className="sales-search-reset-btn"
                    onClick={() => {
                      handleResetSearch();
                      setActiveFilter('all');
                    }}
                  >
                    <X size={13} />
                    <span>Reset</span>
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ── 4. Sales List or Empty State ───────────────────── */}
      {isLoading ? (
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div className="table-loader-spinner" style={{ borderColor: '#E11D48', borderTopColor: 'transparent', width: '32px', height: '32px' }} />
        </div>
      ) : allSales.length === 0 ? (
        <div className="sales-empty-state">
          <div className="sales-empty-icon-circle">
            <Receipt size={40} />
          </div>
          <div className="sales-empty-title">
            {activeSearchQuery ? 'No orders match your search' : 'No sales records found'}
          </div>
          <div className="sales-empty-desc">
            {activeSearchQuery
              ? 'Try searching with a different keyword or reset filters.'
              : 'Orders completed in the Cart POS will immediately appear here.'}
          </div>
          <button
            type="button"
            style={{
              padding: '10px 18px',
              background: '#E11D48',
              color: '#ffffff',
              border: 'none',
              borderRadius: '10px',
              fontSize: '13px',
              fontWeight: 600,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
            }}
            onClick={handleRefresh}
          >
            <RotateCw size={15} />
            <span>Reload Sales</span>
          </button>
        </div>
      ) : (
        <div className="sales-list-container">
          {allSales.map((sale) => {
            const method = (sale.payment_method || 'cash').toLowerCase();
            const badgeClass =
              method === 'cash'
                ? 'sale-payment-badge--cash'
                : method === 'card'
                ? 'sale-payment-badge--card'
                : method === 'qr'
                ? 'sale-payment-badge--qr'
                : 'sale-payment-badge--other';

            return (
              <div
                key={sale.id}
                className="sale-item-card"
                onClick={() => setDetailSale(sale)}
              >
                <div className="sale-item-icon-box">
                  <Receipt size={22} />
                </div>

                <div className="sale-item-main">
                  <div className="sale-item-top-row">
                    <span className="sale-item-receipt-num">
                      {formatReceiptNumber(sale.id, sale.created_at)}
                    </span>
                    {sale.refund_status === 'full' ? (
                      <span className="sale-status-badge" style={{ background: '#FFE4E6', color: '#BE123C', borderColor: '#FECDD3' }}>
                        <RotateCcw size={12} />
                        <span>Refunded</span>
                      </span>
                    ) : sale.refund_status === 'partial' ? (
                      <span className="sale-status-badge" style={{ background: '#FEF3C7', color: '#D97706', borderColor: '#FDE68A' }}>
                        <RotateCcw size={12} />
                        <span>Partially Refunded</span>
                      </span>
                    ) : (
                      <span className="sale-status-badge">
                        <BadgeCheck size={12} />
                        <span>Completed</span>
                      </span>
                    )}
                  </div>

                  <div className="sale-item-meta-row">
                    <div className="sale-meta-group">
                      <User size={13} color="#94A3B8" />
                      <span className="sale-customer-name">
                        {sale.customer_name || 'Walk-in Customer'}
                      </span>
                      {sale.customer_phone && (
                        <span style={{ color: '#94A3B8', fontSize: '11px' }}>
                          ({sale.customer_phone})
                        </span>
                      )}
                      <button
                        type="button"
                        className="history-print-btn"
                        title="Print / Reprint Receipt"
                        onClick={(e) => handlePrintSale(sale, e)}
                        disabled={printingSaleId === sale.id}
                      >
                        <Printer size={12} />
                        <span>{printingSaleId === sale.id ? 'Printing...' : 'Print'}</span>
                      </button>
                    </div>

                    {sale.staff_name && (
                      <span className="sale-staff-pill">
                        <User size={11} color="#64748B" />
                        <span>{sale.staff_name}</span>
                      </span>
                    )}

                    <div className="sale-meta-group">
                      <Clock size={13} color="#94A3B8" />
                      <span>{formatDateTime(sale.created_at)}</span>
                    </div>
                  </div>
                </div>

                <div className="sale-item-right">
                  <span className="sale-item-total">${fmtMoney(sale.total_amount)}</span>
                  <span className={`sale-payment-badge ${badgeClass}`}>
                    {getPaymentMethodLabel(sale.payment_method)}
                  </span>
                </div>

                <ChevronRight size={18} className="sale-chevron" />
              </div>
            );
          })}
        </div>
      )}

      {/* ── 5. Pagination Controls ─────────────────────────── */}
      {!isLoading && allSales.length > 0 && (
        <div className="sales-pagination-bar">
          <span className="sales-pagination-info">
            Showing {startItem} - {endItem} of {totalCount} records (Page {currentPage} of {totalPages})
          </span>

          <div className="sales-pagination-btns">
            <button
              type="button"
              className="sales-page-nav-btn"
              disabled={currentPage <= 1}
              onClick={() => handlePageChange(currentPage - 1)}
            >
              <ChevronLeft size={16} />
              <span>Prev</span>
            </button>

            {/* Page number buttons */}
            {totalPages <= 7 ? (
              Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
                <button
                  key={p}
                  type="button"
                  className={`sales-page-num-btn ${p === currentPage ? 'sales-page-num-btn--active' : ''}`}
                  onClick={() => handlePageChange(p)}
                >
                  {p}
                </button>
              ))
            ) : (
              <>
                <button
                  type="button"
                  className={`sales-page-num-btn ${currentPage === 1 ? 'sales-page-num-btn--active' : ''}`}
                  onClick={() => handlePageChange(1)}
                >
                  1
                </button>
                {currentPage > 3 && (
                  <span style={{ padding: '0 4px', color: '#94A3B8', fontSize: '12px' }}>...</span>
                )}
                {Array.from(
                  { length: 3 },
                  (_, i) => Math.max(2, Math.min(totalPages - 1, currentPage - 1 + i))
                )
                  .filter((v, idx, arr) => arr.indexOf(v) === idx && v > 1 && v < totalPages)
                  .map((p) => (
                    <button
                      key={p}
                      type="button"
                      className={`sales-page-num-btn ${p === currentPage ? 'sales-page-num-btn--active' : ''}`}
                      onClick={() => handlePageChange(p)}
                    >
                      {p}
                    </button>
                  ))}
                {currentPage < totalPages - 2 && (
                  <span style={{ padding: '0 4px', color: '#94A3B8', fontSize: '12px' }}>...</span>
                )}
                <button
                  type="button"
                  className={`sales-page-num-btn ${currentPage === totalPages ? 'sales-page-num-btn--active' : ''}`}
                  onClick={() => handlePageChange(totalPages)}
                >
                  {totalPages}
                </button>
              </>
            )}

            <button
              type="button"
              className="sales-page-nav-btn"
              disabled={currentPage >= totalPages}
              onClick={() => handlePageChange(currentPage + 1)}
            >
              <span>Next</span>
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}

      {/* ── 6. Detail Modal (Tax Receipt & Order Details) ──── */}
      {detailSale && (
        <div className="cart-modal-overlay" onClick={() => setDetailSale(null)}>
          <div className="sale-detail-dialog" onClick={(e) => e.stopPropagation()} role="dialog">
            {/* Header */}
            <div className="sale-detail-header">
              <div>
                <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 800, color: '#0F172A', fontFamily: 'var(--font-display)' }}>
                  Tax Receipt & Order Details
                </h3>
                <div style={{ fontSize: '12px', color: '#64748B', fontWeight: 600, marginTop: '2px' }}>
                  {formatReceiptNumber(detailSale.id, detailSale.created_at)}
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                {detailSale.refund_status === 'full' ? (
                  <span className="sale-status-badge" style={{ fontSize: '11px', padding: '3px 10px', background: '#FFE4E6', color: '#BE123C', borderColor: '#FECDD3' }}>
                    <RotateCcw size={13} />
                    <span>Refunded</span>
                  </span>
                ) : detailSale.refund_status === 'partial' ? (
                  <span className="sale-status-badge" style={{ fontSize: '11px', padding: '3px 10px', background: '#FEF3C7', color: '#D97706', borderColor: '#FDE68A' }}>
                    <RotateCcw size={13} />
                    <span>Partially Refunded</span>
                  </span>
                ) : (
                  <span className="sale-status-badge" style={{ fontSize: '11px', padding: '3px 10px' }}>
                    <BadgeCheck size={13} />
                    <span>Completed</span>
                  </span>
                )}
                <button
                  type="button"
                  className="sale-detail-header-close-btn"
                  onClick={() => setDetailSale(null)}
                  aria-label="Close"
                >
                  <X size={18} />
                </button>
              </div>
            </div>

            {/* Scrollable Inner Content */}
            <div className="sale-detail-body">
              {/* Linked Appointment Banner */}
              {detailSale.appointment_id && (
                <div className="sale-linked-appt-banner">
                  <CalendarCheck size={16} />
                  <span>Linked Appointment: #{detailSale.appointment_id}</span>
                  {detailSale.staff_name && (
                    <span style={{ marginLeft: 'auto', fontWeight: 600, color: '#065F46' }}>
                      Attendant: {detailSale.staff_name}
                    </span>
                  )}
                </div>
              )}

              {/* Customer & Timestamp Grid */}
              <div className="sale-detail-grid">
                <div>
                  <div style={{ fontSize: '11px', color: '#94A3B8', fontWeight: 500 }}>Customer</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '2px' }}>
                    <span style={{ fontSize: '13px', fontWeight: 600, color: '#0F172A' }}>
                      {detailSale.customer_name || 'Walk-in Guest'}
                    </span>
                    <button
                      type="button"
                      className="history-print-btn"
                      title="Print / Reprint Receipt"
                      onClick={(e) => handlePrintSale(detailSale, e)}
                      disabled={printingSaleId === detailSale.id}
                    >
                      <Printer size={12} />
                      <span>{printingSaleId === detailSale.id ? 'Printing...' : 'Print'}</span>
                    </button>
                  </div>
                  {detailSale.customer_phone && (
                    <div style={{ fontSize: '11.5px', color: '#64748B' }}>{detailSale.customer_phone}</div>
                  )}
                </div>

                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: '11px', color: '#94A3B8', fontWeight: 500 }}>Date & Time</div>
                  <div style={{ fontSize: '12px', fontWeight: 600, color: '#0F172A', marginTop: '2px' }}>
                    {formatDateTime(detailSale.created_at)}
                  </div>
                  {detailSale.staff_name && !detailSale.appointment_id && (
                    <div style={{ fontSize: '11.5px', color: '#64748B' }}>Attendant: {detailSale.staff_name}</div>
                  )}
                </div>
              </div>

              {/* Purchased Items List */}
              <div className="sale-detail-items-header" style={{ fontSize: '12.5px', fontWeight: 700, color: '#0F172A', marginBottom: '8px' }}>
                Purchased Items ({detailSale.items?.length || 0})
              </div>
              <div className="sale-detail-items-box">
                {detailSale.items?.map((it, idx) => {
                  const key = String(it.product_id || it.product_name);
                  const refundedQty = (detailSale.refunds || []).reduce((sum, rf) => {
                    const match = (rf.items || []).find((rIt: any) => String(rIt.product_id || rIt.product_name) === key);
                    return sum + (match ? Number(match.quantity) || 0 : 0);
                  }, 0);
                  const remainingQty = Math.max(0, it.quantity - refundedQty);

                  return (
                    <div key={idx} className={`sale-detail-item-row ${refundedQty > 0 ? 'has-refund' : ''}`}>
                      <span className="sale-detail-item-name">
                        {it.product_name}
                      </span>
                      <div className="sale-detail-item-right">
                        {refundedQty > 0 ? (
                          <div className="sale-detail-refund-tags">
                            <span className={`sale-refund-tag ${remainingQty === 0 ? 'full' : ''}`}>
                              Refund ×{refundedQty}
                            </span>
                            <span className={`sale-remaining-unrefunded ${remainingQty === 0 ? 'zero' : ''}`}>
                              {remainingQty === 0 ? '(0 unrefunded)' : `(${remainingQty} unrefunded)`}
                            </span>
                            <span className="sale-detail-item-orig-qty">
                              Orig: ×{it.quantity}
                            </span>
                          </div>
                        ) : (
                          <span className="sale-detail-item-qty">
                            ×{it.quantity}
                          </span>
                        )}
                        <span
                          className="sale-detail-item-price"
                          style={remainingQty === 0 ? { textDecoration: 'line-through', opacity: 0.6 } : undefined}
                        >
                          ${fmtMoney(it.line_total)}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Financial Totals */}
              {(() => {
                const sRefunds = detailSale.refunds || [];
                const gstRefunded =
                  detailSale.gst_reversed_total !== undefined
                    ? Number(detailSale.gst_reversed_total)
                    : sRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.gst_reversed_total) || 0), 0);
                const netTax =
                  detailSale.net_tax_amount !== undefined
                    ? Number(detailSale.net_tax_amount)
                    : Math.max(0, Math.round(((Number(detailSale.tax_amount) || 0) - gstRefunded) * 100) / 100);

                const subtotalRefunded =
                  detailSale.subtotal_refunded_total !== undefined
                    ? Number(detailSale.subtotal_refunded_total)
                    : sRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.subtotal_refunded) || 0), 0);
                const netSubtotal =
                  detailSale.net_subtotal !== undefined
                    ? Number(detailSale.net_subtotal)
                    : Math.max(0, Math.round(((Number(detailSale.subtotal) || 0) - subtotalRefunded) * 100) / 100);

                const hasRefunds = Number(detailSale.refunded_amount) > 0 || sRefunds.length > 0;
                const displaySubtotal = hasRefunds ? netSubtotal : Number(detailSale.subtotal);
                const displayTax = hasRefunds ? netTax : Number(detailSale.tax_amount);

                return (
                  <div className="sale-detail-totals">
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#64748B' }}>
                      <span>Subtotal</span>
                      <span style={{ fontWeight: 600, color: '#0F172A' }}>
                        ${fmtMoney(displaySubtotal)}
                        {subtotalRefunded > 0 && (
                          <span style={{ fontSize: '11px', color: '#BE123C', fontWeight: 500, marginLeft: '6px' }}>
                            (-${fmtMoney(subtotalRefunded)} refunded)
                          </span>
                        )}
                      </span>
                    </div>
                    {Number(detailSale.item_discount_total) > 0 && (
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#E11D48' }}>
                        <span>Item Discounts</span>
                        <span style={{ fontWeight: 600 }}>-${fmtMoney(detailSale.item_discount_total)}</span>
                      </div>
                    )}
                    {Number(detailSale.overall_discount) > 0 && (
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#E11D48' }}>
                        <span>Overall Discount</span>
                        <span style={{ fontWeight: 600 }}>-${fmtMoney(detailSale.overall_discount)}</span>
                      </div>
                    )}
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#64748B' }}>
                      <span>Tax (8%)</span>
                      <span style={{ fontWeight: 600, color: '#0F172A' }}>
                        ${fmtMoney(displayTax)}
                        {gstRefunded > 0 && (
                          <span style={{ fontSize: '11px', color: '#BE123C', fontWeight: 500, marginLeft: '6px' }}>
                            (-${fmtMoney(gstRefunded)} refunded)
                          </span>
                        )}
                      </span>
                    </div>

                    <div className="sale-detail-total-paid">
                      <span>Total Paid</span>
                      <span style={{ color: '#E11D48' }}>${fmtMoney(detailSale.total_amount)}</span>
                    </div>

                    {hasRefunds && (
                      <>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#BE123C', marginTop: '4px' }}>
                          <span>Total Refunded</span>
                          <span style={{ fontWeight: 700 }}>-${fmtMoney(detailSale.refunded_amount)}</span>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#0F172A', marginTop: '4px', paddingTop: '4px', borderTop: '1px dashed #CBD5E1' }}>
                          <span style={{ fontWeight: 600 }}>Net Retained Balance</span>
                          <span style={{ fontWeight: 800, color: '#059669' }}>
                            ${fmtMoney(Math.max(0, Number(detailSale.total_amount) - Number(detailSale.refunded_amount)))}
                          </span>
                        </div>
                      </>
                    )}

                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: '#64748B', marginTop: '6px' }}>
                      <span>Payment Method</span>
                      <span style={{ fontWeight: 600, color: '#0F172A' }}>
                        {getPaymentMethodLabel(detailSale.payment_method)} (Tendered: ${fmtMoney(detailSale.amount_tendered || detailSale.total_amount)})
                      </span>
                    </div>

                    {Number(detailSale.change_amount) > 0 && (
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: '#64748B', marginTop: '2px' }}>
                        <span>Change Returned</span>
                        <span style={{ fontWeight: 600, color: '#059669' }}>
                          ${fmtMoney(detailSale.change_amount)}
                        </span>
                      </div>
                    )}
                  </div>
                );
              })()}

              {/* Refund Audit History Box */}
              {detailSale.refunds && detailSale.refunds.length > 0 && (
                <div className="refund-history-box">
                  <div className="refund-history-header">
                    <span>Refund Audit Trail ({detailSale.refunds.length})</span>
                    <span style={{ color: '#BE123C' }}>
                      Total Refunded: -${fmtMoney(detailSale.refunded_amount)}
                    </span>
                  </div>
                  {detailSale.refunds.map((rf, rIdx) => (
                    <div key={rIdx} className="refund-history-item">
                      <div className="refund-history-left">
                        <span className="refund-history-no">{rf.refund_receipt_number}</span>
                        <span className="refund-history-date">
                          {formatDateTime(rf.created_at)} • {rf.refund_method?.toUpperCase()}
                          {rf.reason ? ` • ${rf.reason}` : ''}
                        </span>
                        <span style={{ fontSize: '11px', color: '#64748B', marginTop: '2px' }}>
                          Items: {(rf.items || []).map((ri) => `${ri.product_name} (×${ri.quantity})`).join(', ')}
                        </span>
                      </div>
                      <span className="refund-history-amount">
                        -${fmtMoney(rf.total_refund_amount)}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Fixed Footer: Refund Button on Left Side of Close Button */}
            <div className="sale-detail-footer" style={{ display: 'flex', gap: '10px' }}>
              <button
                type="button"
                className="sale-detail-refund-btn"
                onClick={() => setShowRefundModal(true)}
                disabled={detailSale.refund_status === 'full'}
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px',
                  padding: '12px',
                  backgroundColor: detailSale.refund_status === 'full' ? '#F1F5F9' : '#E11D48',
                  color: detailSale.refund_status === 'full' ? '#94A3B8' : '#ffffff',
                  border: 'none',
                  borderRadius: '10px',
                  fontSize: '13px',
                  fontWeight: 600,
                  cursor: detailSale.refund_status === 'full' ? 'not-allowed' : 'pointer',
                  transition: 'all 0.15s ease',
                }}
              >
                <RotateCcw size={15} />
                <span>
                  {detailSale.refund_status === 'full' ? 'Fully Refunded' : 'Refund'}
                </span>
              </button>

              <button
                type="button"
                className="sale-detail-close-btn"
                onClick={() => setDetailSale(null)}
                style={{ flex: 1 }}
              >
                <X size={16} />
                <span>Close</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── 7. Refund Modal Popup ──────────────────────────── */}
      {showRefundModal && detailSale && (
        <RefundModal
          isOpen={showRefundModal}
          onClose={() => setShowRefundModal(false)}
          type="sale"
          transaction={detailSale}
          onRefundSuccess={handleRefundSuccess}
        />
      )}
    </div>
  );
}
