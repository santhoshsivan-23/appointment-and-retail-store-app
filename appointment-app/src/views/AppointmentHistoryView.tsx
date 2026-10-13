import { useState, useEffect, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import {
  RotateCw,
  RotateCcw,
  CheckCircle2,
  Calendar,
  DollarSign,
  Search,
  X,
  ChevronRight,
  ChevronLeft,
  ChevronDown,
  User,
  Phone,
  Clock,
  ShieldCheck,
  History,
  Printer,
  BadgeCheck,
} from 'lucide-react';
import { appointmentApi, type Appointment, type AppointmentSummary } from '../api/appointmentApi';
import { staffApi, type Staff } from '../api/staffApi';
import { useAppSelector } from '../store/hooks';
import { executeReceiptPrint } from '../utils/receiptPrinter';
import RefundModal from '../components/RefundModal';
import DateRangeFilter from '../components/DateRangeFilter';
import '../styles/appointment_history.css';
import '../styles/refund_modal.css';

const PAGE_SIZE = 20;

/* ── Safe Currency Formatter ───────────────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

/* ── Format Date Time ──────────────────────────────────── */
const formatDateTime = (dtStr?: string) => {
  if (!dtStr) return 'N/A';
  try {
    const d = new Date(dtStr);
    return d.toLocaleDateString('en-GB', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return dtStr;
  }
};

/* ── Normalize Appointment Helper ──────────────────────── */
const normalizeAppointment = (a: any): Appointment => {
  let parsedServices: any[] = [];
  if (a.services) {
    if (Array.isArray(a.services)) {
      parsedServices = a.services;
    } else if (typeof a.services === 'string') {
      try {
        parsedServices = JSON.parse(a.services);
      } catch {
        parsedServices = [];
      }
    }
  }

  let parsedRefunds: any[] = [];
  if (a.refunds) {
    if (Array.isArray(a.refunds)) {
      parsedRefunds = a.refunds;
    } else if (typeof a.refunds === 'string') {
      try {
        parsedRefunds = JSON.parse(a.refunds);
      } catch {
        parsedRefunds = [];
      }
    }
  }

  const aRefunds = parsedRefunds;
  const totalGstRefunded =
    a.gst_reversed_total !== undefined
      ? Number(a.gst_reversed_total)
      : aRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.gst_reversed_total) || 0), 0);
  const totalSubtotalRefunded =
    a.subtotal_refunded_total !== undefined
      ? Number(a.subtotal_refunded_total)
      : aRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.subtotal_refunded) || 0), 0);
  const netTax =
    a.net_tax_amount !== undefined
      ? Number(a.net_tax_amount)
      : Math.max(0, Math.round(((Number(a.tax_amount) || 0) - totalGstRefunded) * 100) / 100);
  const netSubtotal =
    a.net_subtotal !== undefined
      ? Number(a.net_subtotal)
      : Math.max(0, Math.round(((Number(a.subtotal || a.total_amount) || 0) - totalSubtotalRefunded) * 100) / 100);

  return {
    ...a,
    total_amount: Number(a.total_amount) || 0,
    services: parsedServices,
    refunds: parsedRefunds,
    refund_status: a.refund_status || 'none',
    refunded_amount: Number(a.refunded_amount) || 0,
    customer_name: a.customer_name || 'Walk-in Customer',
    customer_phone: a.customer_phone || '',
    staff_name: a.staff_name || '',
    notes: a.notes || '',
    gst_reversed_total: totalGstRefunded,
    net_tax_amount: netTax,
    subtotal_refunded_total: totalSubtotalRefunded,
    net_subtotal: netSubtotal,
  };
};

export default function AppointmentHistoryView() {
  /* ── Date Defaults (Today by default) ──────────────────── */
  const todayStr = useMemo(() => {
    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }, []);

  const [startDate, setStartDate] = useState<string>(todayStr);
  const [endDate, setEndDate] = useState<string>(todayStr);

  /* ── State ────────────────────────────────────────────── */
  const [displayAppointments, setDisplayAppointments] = useState<Appointment[]>([]);
  const [totalCount, setTotalCount] = useState<number>(0);
  const [totalPages, setTotalPages] = useState<number>(1);
  const [summary, setSummary] = useState<AppointmentSummary>({
    total: 0,
    completed: 0,
    total_revenue: 0,
  });

  const [staffList, setStaffList] = useState<Staff[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSearching, setIsSearching] = useState<boolean>(false);

  const [searchInput, setSearchInput] = useState<string>('');
  const [activeSearchQuery, setActiveSearchQuery] = useState<string>('');
  const [isPanelExpanded, setIsPanelExpanded] = useState<boolean>(true);
  const [currentPage, setCurrentPage] = useState<number>(1);
  const [detailAppointment, setDetailAppointment] = useState<Appointment | null>(null);
  const [showRefundModal, setShowRefundModal] = useState<boolean>(false);

  const printerSettings = useAppSelector((state) => state.printer.settings);
  const [printingAptId, setPrintingAptId] = useState<number | null>(null);

  /* ── Print / Reprint Handler ───────────────────────────── */
  const handlePrintAppointment = async (aptToPrint: Appointment, e?: React.MouseEvent) => {
    if (e) {
      e.stopPropagation();
    }
    setPrintingAptId(aptToPrint.id);
    try {
      let fullApt = { ...aptToPrint };
      if (!fullApt.refunds || fullApt.refunds.length === 0) {
        try {
          const rfRes = await appointmentApi.getRefunds(aptToPrint.id);
          if (rfRes.data?.data && Array.isArray(rfRes.data.data)) {
            fullApt.refunds = rfRes.data.data;
          }
        } catch (_) {}
      }
      const aptRefunds = fullApt.refunds || [];
      const totalGstRefunded =
        fullApt.gst_reversed_total !== undefined
          ? Number(fullApt.gst_reversed_total)
          : aptRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.gst_reversed_total) || 0), 0);
      const totalSubtotalRefunded =
        fullApt.subtotal_refunded_total !== undefined
          ? Number(fullApt.subtotal_refunded_total)
          : aptRefunds.reduce((sum: number, rf: any) => sum + (Number(rf.subtotal_refunded) || 0), 0);
      fullApt.gst_reversed_total = totalGstRefunded;
      fullApt.net_tax_amount = Math.max(0, Math.round(((Number(fullApt.tax_amount) || 0) - totalGstRefunded) * 100) / 100);
      fullApt.subtotal_refunded_total = totalSubtotalRefunded;
      fullApt.net_subtotal = Math.max(0, Math.round(((Number(fullApt.subtotal || fullApt.total_amount) || 0) - totalSubtotalRefunded) * 100) / 100);

      await executeReceiptPrint({
        printerSettings,
        transaction: fullApt,
        type: 'appointment',
        isReprint: true,
      });
    } catch (err: any) {
      console.error('Print appointment error:', err);
      toast.error('Failed to trigger receipt printing.');
    } finally {
      setPrintingAptId(null);
    }
  };

  /* ── Handle Refund Success Callback ───────────────────── */
  const handleRefundSuccess = (updatedApt: Appointment, _refundRecord?: any) => {
    const normalized = normalizeAppointment(updatedApt);
    setDetailAppointment(normalized);
    setDisplayAppointments((prev) =>
      prev.map((a) => (a.id === normalized.id ? normalized : a))
    );
    fetchSummary(startDate, endDate, activeSearchQuery);
  };

  /* ── Sort & Filter Completed Appointments Helper ─────── */
  const processList = (rawList: any[]): Appointment[] => {
    const completed = rawList
      .map(normalizeAppointment)
      .filter((a) => {
        const s = (a.status || '').toLowerCase().trim();
        return s === 'completed' || s === 'performed';
      });

    completed.sort((a, b) => {
      const cmp = (b.appointment_date || '').localeCompare(a.appointment_date || '');
      if (cmp !== 0) return cmp;
      return (b.start_time || '').localeCompare(a.start_time || '');
    });

    return completed;
  };

  /* ── 1. Fetch Summary API ─────────────────────────────── */
  const fetchSummary = useCallback(async (start: string, end: string, query?: string) => {
    try {
      const res = await appointmentApi.getSummary({
        start_date: start,
        end_date: end,
        search: query || undefined,
      });
      if (res.data?.data) {
        setSummary(res.data.data);
      }
    } catch (err) {
      console.error('Error fetching appointment summary:', err);
    }
  }, []);

  /* ── 2. Fetch History Data API (Backend Paginated) ─────── */
  const fetchAppointments = useCallback(
    async (pageToLoad: number, start: string, end: string, query?: string) => {
      setIsLoading(true);
      try {
        const res = await appointmentApi.getAppointments({
          start_date: start,
          end_date: end,
          status: 'completed',
          search: query || undefined,
          page: pageToLoad,
          limit: PAGE_SIZE,
        });
        const rawList = res.data?.data ?? [];
        const apts = processList(rawList);
        setDisplayAppointments(apts);
        const total = res.data?.total ?? apts.length;
        setTotalCount(total);
        setTotalPages(res.data?.totalPages ?? Math.max(1, Math.ceil(total / PAGE_SIZE)));
        setCurrentPage(pageToLoad);
      } catch (err) {
        console.error('Error loading appointment history:', err);
        toast.error('Failed to load appointment history');
      } finally {
        setIsLoading(false);
      }
    },
    []
  );

  /* ── Initial Load ─────────────────────────────────────── */
  useEffect(() => {
    staffApi.getAll(true).then((res) => {
      setStaffList(res.data?.data ?? []);
    }).catch((err) => console.error(err));

    fetchAppointments(1, todayStr, todayStr);
    fetchSummary(todayStr, todayStr);
  }, [fetchAppointments, fetchSummary, todayStr]);

  /* ── Date Range Change Handler ────────────────────────── */
  const handleDateRangeChange = (newStart: string, newEnd: string) => {
    setStartDate(newStart);
    setEndDate(newEnd);
    fetchAppointments(1, newStart, newEnd, activeSearchQuery);
    fetchSummary(newStart, newEnd, activeSearchQuery);
  };

  /* ── Page Change Handler (Loads only current page records) */
  const handlePageChange = (newPage: number) => {
    fetchAppointments(newPage, startDate, endDate, activeSearchQuery);
  };

  /* ── Search Handlers ──────────────────────────────────── */
  const handlePerformSearch = async () => {
    const query = searchInput.trim();
    setIsSearching(true);
    setActiveSearchQuery(query);
    try {
      await Promise.all([
        fetchAppointments(1, startDate, endDate, query.length > 0 ? query : undefined),
        fetchSummary(startDate, endDate, query.length > 0 ? query : undefined),
      ]);
    } finally {
      setIsSearching(false);
    }
  };

  const handleResetSearch = () => {
    setSearchInput('');
    setActiveSearchQuery('');
    fetchAppointments(1, startDate, endDate);
    fetchSummary(startDate, endDate);
  };

  /* ── Reload Handler ───────────────────────────────────── */
  const handleRefresh = () => {
    fetchAppointments(currentPage, startDate, endDate, activeSearchQuery);
    fetchSummary(startDate, endDate, activeSearchQuery);
  };

  /* ── Pagination Bounds ────────────────────────────────── */
  const startItem = totalCount === 0 ? 0 : (currentPage - 1) * PAGE_SIZE + 1;
  const endItem = Math.min(currentPage * PAGE_SIZE, totalCount);

  /* ── Helper to resolve staff role ─────────────────────── */
  const getStaffRole = (staffId?: number | null) => {
    if (!staffId) return '';
    const st = staffList.find((s) => s.id === staffId);
    return st ? st.role : `Staff #${staffId}`;
  };

  return (
    <div className="appointment-history-container">
      {/* ── Main Collapsible Card Container ────────────────── */}
      <div className="apt-main-card">
        {/* Main Header (Always Visible) */}
        <div
          className={`apt-main-card__header ${isPanelExpanded ? 'apt-main-card__header--expanded' : ''}`}
          onClick={() => setIsPanelExpanded((prev) => !prev)}
        >
          <div className="apt-main-card__header-left">
            <h1 className="apt-main-card__title">Appointment History</h1>
            <div className="apt-main-card__badge">
              {summary.completed} Performed
            </div>
          </div>

          <div className="apt-main-card__header-right">
            <button
              type="button"
              className="apt-refresh-btn"
              onClick={(e) => {
                e.stopPropagation();
                handleRefresh();
              }}
              disabled={isLoading}
              title="Refresh appointment history"
            >
              <RotateCw size={15} className={isLoading ? 'apt-spin' : ''} style={{ color: '#E11D48' }} />
              <span>Refresh</span>
            </button>

            {/* Dropdown / Expand-Collapse Button */}
            <button
              type="button"
              className={`apt-toggle-btn ${!isPanelExpanded ? 'apt-toggle-btn--collapsed' : ''}`}
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

        {/* Collapsible Content: 3 KPI Cards + Date Range & Search Bar */}
        <div className={`apt-main-card__collapsible ${!isPanelExpanded ? 'apt-main-card__collapsible--collapsed' : ''}`}>
          <div className="apt-main-card__collapsible-inner">
            {/* 2. Compact KPI Metrics Summary from Summary API */}
            <div className="apt-metrics-row">
              {/* Total Appointments */}
              <div className="apt-metric-card">
                <div className="apt-metric-icon" style={{ background: '#EFF6FF', color: '#2563EB' }}>
                  <Calendar size={18} />
                </div>
                <div className="apt-metric-info">
                  <div className="apt-metric-title">Total Appointments</div>
                  <div className="apt-metric-value">{summary.total} Booked</div>
                  <div className="apt-metric-sub">In selected date range</div>
                </div>
              </div>

              {/* Completed Appointments */}
              <div className="apt-metric-card">
                <div className="apt-metric-icon" style={{ background: '#ECFDF5', color: '#10B981' }}>
                  <CheckCircle2 size={18} />
                </div>
                <div className="apt-metric-info">
                  <div className="apt-metric-title">Completed Appointments</div>
                  <div className="apt-metric-value">{summary.completed} Completed</div>
                  <div className="apt-metric-sub">100% fulfilled &amp; performed</div>
                </div>
              </div>

              {/* Total Revenue */}
              <div className="apt-metric-card">
                <div className="apt-metric-icon" style={{ background: '#F5F3FF', color: '#8B5CF6' }}>
                  <DollarSign size={18} />
                </div>
                <div className="apt-metric-info">
                  <div className="apt-metric-title">Total Revenue</div>
                  <div className="apt-metric-value">${fmtMoney(summary.total_revenue)}</div>
                  <div className="apt-metric-sub">Total earned from performed sessions</div>
                </div>
              </div>
            </div>

            {/* 3. Date Range Filter & Search Bar */}
            <div className="apt-search-bar">
              <div className="apt-search-section">
                {/* Modern Date Range Filter Popup */}
                <DateRangeFilter
                  startDate={startDate}
                  endDate={endDate}
                  onChange={handleDateRangeChange}
                  className="apt-date-range-filter"
                />

                <div className="apt-search-row">
                  <div className="apt-search-box">
                    <Search size={16} className="apt-search-box__icon" />
                    <input
                      type="text"
                      className="apt-search-input"
                      placeholder="Search customer name, phone, or staff..."
                      value={searchInput}
                      onChange={(e) => setSearchInput(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handlePerformSearch();
                      }}
                    />
                    {searchInput && (
                      <button
                        type="button"
                        className="apt-search-clear-btn"
                        onClick={() => {
                          setSearchInput('');
                          if (activeSearchQuery) handleResetSearch();
                        }}
                      >
                        <X size={14} />
                      </button>
                    )}
                  </div>

                  <button
                    type="button"
                    className="apt-btn-apply"
                    onClick={handlePerformSearch}
                    disabled={isSearching}
                  >
                    {isSearching ? (
                      <RotateCw size={13} className="apt-spin" />
                    ) : (
                      <Search size={13} />
                    )}
                    <span>Apply</span>
                  </button>

                  {activeSearchQuery && (
                    <button
                      type="button"
                      className="apt-btn-reset"
                      onClick={handleResetSearch}
                    >
                      <X size={13} />
                      <span>Reset</span>
                    </button>
                  )}
                </div>
              </div>

              <div className="apt-audit-badge">
                <ShieldCheck size={14} />
                <span>Audit-Safe Performed Retention</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 4. Completed Appointments List / Empty State */}
      <div className="apt-history-list-wrapper">
        {isLoading ? (
          <div className="apt-empty-state">
            <RotateCw size={36} className="apt-spin" style={{ color: '#E11D48', marginBottom: 16 }} />
            <div className="apt-empty-desc">Loading appointment history...</div>
          </div>
        ) : displayAppointments.length === 0 ? (
          <div className="apt-empty-state">
            <div className="apt-empty-icon">
              <History size={40} />
            </div>
            <div className="apt-empty-title">
              {activeSearchQuery
                ? 'No completed appointments match your search'
                : 'No performed appointments yet'}
            </div>
            <div className="apt-empty-desc">
              {activeSearchQuery
                ? 'Try searching with a different name, date, or appointment #.'
                : 'Appointments marked as "Completed" will automatically be recorded here.'}
            </div>
            <button
              type="button"
              className="apt-empty-reload-btn"
              onClick={handleRefresh}
            >
              <RotateCw size={15} />
              <span>Reload History</span>
            </button>
          </div>
        ) : (
          <div className="apt-history-list">
            {displayAppointments.map((a) => (
              <div
                key={a.id}
                className="apt-history-card"
                onClick={() => setDetailAppointment(a)}
              >
                {/* 1. Appointment Number */}
                <div className="apt-card-number">
                  #APT-{String(a.id).padStart(4, '0')}
                </div>

                {/* 2. Customer Name, Phone & Staff */}
                <div className="apt-card-info">
                  <div className="apt-card-customer">
                    <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                      <User size={15} style={{ color: '#94A3B8' }} />
                      <span>{a.customer_name || 'Walk-in Customer'}</span>
                    </div>
                    <button
                      type="button"
                      className="history-print-btn"
                      title="Print / Reprint Receipt"
                      onClick={(e) => handlePrintAppointment(a, e)}
                      disabled={printingAptId === a.id}
                    >
                      <Printer size={12} />
                      <span>{printingAptId === a.id ? 'Printing...' : 'Print'}</span>
                    </button>
                  </div>

                  {a.customer_phone && (
                    <div className="apt-card-phone">
                      <Phone size={13} style={{ color: '#94A3B8' }} />
                      <span>{a.customer_phone}</span>
                    </div>
                  )}

                  {a.staff_name && (
                    <div className="apt-card-staff">
                      <BadgeCheck size={13} style={{ color: '#64748B' }} />
                      <span>{a.staff_name}</span>
                    </div>
                  )}

                  {a.appointment_date && (
                    <div className="apt-card-datetime">
                      <Clock size={13} style={{ color: '#94A3B8' }} />
                      <span>{a.appointment_date}{a.start_time ? ` • ${a.start_time}` : ''}</span>
                    </div>
                  )}
                </div>

                {/* 3. Total Amount, Refund Status & Chevron */}
                <div className="apt-card-right">
                  {a.refund_status === 'full' ? (
                    <span
                      style={{
                        fontSize: '11px',
                        fontWeight: 700,
                        padding: '2px 8px',
                        borderRadius: '12px',
                        backgroundColor: '#FEE2E2',
                        color: '#B91C1C',
                        border: '1px solid #FECACA',
                      }}
                    >
                      Refunded
                    </span>
                  ) : a.refund_status === 'partial' ? (
                    <span
                      style={{
                        fontSize: '11px',
                        fontWeight: 700,
                        padding: '2px 8px',
                        borderRadius: '12px',
                        backgroundColor: '#FEF3C7',
                        color: '#B45309',
                        border: '1px solid #FDE68A',
                      }}
                    >
                      Partial Refund
                    </span>
                  ) : null}
                  <div className="apt-card-total">
                    ${fmtMoney(a.total_amount)}
                  </div>
                  <ChevronRight size={18} className="apt-card-chevron" />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* 5. Pagination Controls */}
      {!isLoading && displayAppointments.length > 0 && (
        <div className="apt-pagination-bar">
          <div className="apt-pagination-info">
            Showing {startItem} - {endItem} of {totalCount} records (Page {currentPage} of {totalPages})
          </div>

          <div className="apt-pagination-actions">
            <button
              type="button"
              className="apt-page-nav-btn"
              onClick={() => handlePageChange(currentPage - 1)}
              disabled={currentPage <= 1}
            >
              <ChevronLeft size={16} />
              <span>Prev</span>
            </button>

            {/* Numeric page buttons with standard ellipsis matching Flutter */}
            {totalPages <= 7 ? (
              Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
                <button
                  key={p}
                  type="button"
                  className={`apt-page-num-btn ${p === currentPage ? 'apt-page-num-btn--active' : ''}`}
                  onClick={() => handlePageChange(p)}
                >
                  {p}
                </button>
              ))
            ) : (
              <>
                <button
                  type="button"
                  className={`apt-page-num-btn ${currentPage === 1 ? 'apt-page-num-btn--active' : ''}`}
                  onClick={() => handlePageChange(1)}
                >
                  1
                </button>
                {currentPage > 3 && <span className="apt-page-ellipsis">...</span>}
                {Array.from(
                  { length: 3 },
                  (_, i) => Math.max(2, Math.min(totalPages - 1, currentPage - 1 + i))
                )
                  .filter((v, idx, arr) => arr.indexOf(v) === idx && v > 1 && v < totalPages)
                  .map((p) => (
                    <button
                      key={p}
                      type="button"
                      className={`apt-page-num-btn ${p === currentPage ? 'apt-page-num-btn--active' : ''}`}
                      onClick={() => handlePageChange(p)}
                    >
                      {p}
                    </button>
                  ))}
                {currentPage < totalPages - 2 && <span className="apt-page-ellipsis">...</span>}
                <button
                  type="button"
                  className={`apt-page-num-btn ${currentPage === totalPages ? 'apt-page-num-btn--active' : ''}`}
                  onClick={() => handlePageChange(totalPages)}
                >
                  {totalPages}
                </button>
              </>
            )}

            <button
              type="button"
              className="apt-page-nav-btn"
              onClick={() => handlePageChange(currentPage + 1)}
              disabled={currentPage >= totalPages}
            >
              <span>Next</span>
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}

      {/* 6. Complete Appointment Details Popup Modal */}
      {detailAppointment && (
        <div
          className="apt-modal-overlay"
          onClick={() => setDetailAppointment(null)}
        >
          <div
            className="apt-modal-dialog"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
          >
            {/* Modal Header */}
            <div className="apt-modal-header">
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <h3 className="apt-modal-title">Appointment Details</h3>
                  {detailAppointment.refund_status === 'full' ? (
                    <div className="apt-modal-status-badge" style={{ backgroundColor: '#FEE2E2', color: '#B91C1C' }}>
                      <RotateCcw size={12} />
                      <span>REFUNDED</span>
                    </div>
                  ) : detailAppointment.refund_status === 'partial' ? (
                    <div className="apt-modal-status-badge" style={{ backgroundColor: '#FEF3C7', color: '#B45309' }}>
                      <RotateCcw size={12} />
                      <span>PARTIAL REFUND</span>
                    </div>
                  ) : (
                    <div className="apt-modal-status-badge">
                      <CheckCircle2 size={12} />
                      <span>{String(detailAppointment.status).toUpperCase()}</span>
                    </div>
                  )}
                </div>
                <div className="apt-modal-apt-no">
                  #APT-{String(detailAppointment.id).padStart(4, '0')}
                </div>
              </div>
              <button
                type="button"
                className="apt-modal-header-close-btn"
                onClick={() => setDetailAppointment(null)}
                aria-label="Close"
              >
                <X size={18} />
              </button>
            </div>

            <div className="apt-modal-divider" />

            {/* Scrollable Inner Content */}
            <div className="apt-modal-body">
              {/* Customer & Staff Info */}
              <div className="apt-modal-grid-2">
                <div>
                  <div className="apt-modal-field-label">Customer</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <div className="apt-modal-field-val">
                      {detailAppointment.customer_name || 'Walk-in Guest'}
                    </div>
                    <button
                      type="button"
                      className="history-print-btn"
                      title="Print / Reprint Receipt"
                      onClick={(e) => handlePrintAppointment(detailAppointment, e)}
                      disabled={printingAptId === detailAppointment.id}
                    >
                      <Printer size={12} />
                      <span>{printingAptId === detailAppointment.id ? 'Printing...' : 'Print'}</span>
                    </button>
                  </div>
                  {detailAppointment.customer_phone && (
                    <div className="apt-modal-field-sub">
                      {detailAppointment.customer_phone}
                    </div>
                  )}
                </div>

                <div style={{ textAlign: 'right' }}>
                  <div className="apt-modal-field-label">Assigned Staff</div>
                  <div className="apt-modal-field-val">
                    {detailAppointment.staff_name || `Staff #${detailAppointment.staff_id}`}
                  </div>
                  <div className="apt-modal-field-sub">
                    {getStaffRole(detailAppointment.staff_id)}
                  </div>
                </div>
              </div>

              {/* Schedule Banner */}
              <div className="apt-modal-schedule-box">
                <div className="apt-modal-schedule-item">
                  <Calendar size={15} style={{ color: '#64748B' }} />
                  <span>{detailAppointment.appointment_date}</span>
                </div>
                <div className="apt-modal-schedule-divider" />
                <div className="apt-modal-schedule-item">
                  <Clock size={15} style={{ color: '#64748B' }} />
                  <span>
                    {detailAppointment.start_time} - {detailAppointment.end_time}
                  </span>
                </div>
              </div>

              <div className="apt-modal-divider" />

              {/* Services Performed Breakdown */}
              <div className="apt-modal-services-title">
                Services Performed ({detailAppointment.services?.length || 0})
              </div>

              {!detailAppointment.services || detailAppointment.services.length === 0 ? (
                <div className="apt-modal-field-sub" style={{ fontStyle: 'italic', marginBottom: 12 }}>
                  No specific service items recorded
                </div>
              ) : (
                <div className="apt-modal-services-box">
                  {detailAppointment.services.map((s, idx) => {
                    const sName = s.name || s.product_name || 'Service';
                    const sPrice = Number(s.price !== undefined ? s.price : s.unit_price) || 0;
                    const sQty = Number(s.quantity) || 1;
                    const sKey = String(s.product_id || s.id || sName);

                    // Calculate total units refunded for this service
                    const refundedQty = (detailAppointment.refunds || []).reduce((acc: number, rf: any) => {
                      if (!Array.isArray(rf.items)) return acc;
                      const match = rf.items.find(
                        (item: any) => String(item.product_id || item.product_name) === sKey
                      );
                      return acc + (match ? Number(match.quantity) || 0 : 0);
                    }, 0);
                    const remainingQty = Math.max(0, sQty - refundedQty);

                    return (
                      <div
                        key={idx}
                        className={`apt-modal-service-row ${refundedQty > 0 ? 'has-refund' : ''}`}
                      >
                        <span className="apt-modal-service-name">{sName}</span>
                        <div className="apt-modal-service-right">
                          {refundedQty > 0 ? (
                            <div className="apt-modal-refund-tags">
                              <span className={`sale-refund-tag ${remainingQty === 0 ? 'full' : ''}`}>
                                Refund ×{refundedQty}
                              </span>
                              <span className={`sale-remaining-unrefunded ${remainingQty === 0 ? 'zero' : ''}`}>
                                {remainingQty === 0 ? '(0 unrefunded)' : `(${remainingQty} unrefunded)`}
                              </span>
                              <span className="apt-modal-service-orig-qty">
                                Orig: ×{sQty}
                              </span>
                            </div>
                          ) : sQty > 1 ? (
                            <span className="apt-modal-service-qty">
                              ×{sQty}
                            </span>
                          ) : null}
                          <span
                            className="apt-modal-service-price"
                            style={remainingQty === 0 && refundedQty > 0 ? { textDecoration: 'line-through', opacity: 0.6 } : undefined}
                          >
                            ${fmtMoney(sPrice * sQty)}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* Notes / Observations */}
              {detailAppointment.notes && (
                <div className="apt-modal-notes-box">
                  <div className="apt-modal-notes-title">Notes / Observations</div>
                  <div className="apt-modal-notes-text">{detailAppointment.notes}</div>
                </div>
              )}

              {/* Total Amount & Refund Breakdown */}
              <div className="apt-modal-total-row">
                <span className="apt-modal-total-label">Total Amount</span>
                <span className="apt-modal-total-value">
                  ${fmtMoney(detailAppointment.total_amount)}
                </span>
              </div>

              {Number(detailAppointment.refunded_amount) > 0 && (
                <>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#BE123C', marginTop: '6px' }}>
                    <span>Total Refunded</span>
                    <span style={{ fontWeight: 700 }}>-${fmtMoney(detailAppointment.refunded_amount)}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#0F172A', marginTop: '6px', paddingTop: '6px', borderTop: '1px dashed #CBD5E1' }}>
                    <span style={{ fontWeight: 600 }}>Net Retained Balance</span>
                    <span style={{ fontWeight: 800, color: '#059669' }}>
                      ${fmtMoney(Math.max(0, Number(detailAppointment.total_amount) - Number(detailAppointment.refunded_amount)))}
                    </span>
                  </div>
                </>
              )}

              {/* Refund Audit History Box */}
              {detailAppointment.refunds && detailAppointment.refunds.length > 0 && (
                <div className="refund-history-box" style={{ marginTop: '12px' }}>
                  <div className="refund-history-header">
                    <span>Refund Audit Trail ({detailAppointment.refunds.length})</span>
                    <span style={{ color: '#BE123C' }}>
                      Total Refunded: -${fmtMoney(detailAppointment.refunded_amount)}
                    </span>
                  </div>
                  {detailAppointment.refunds.map((rf: any, rIdx: number) => (
                    <div key={rIdx} className="refund-history-item">
                      <div className="refund-history-left">
                        <span className="refund-history-no">{rf.refund_receipt_number}</span>
                        <span className="refund-history-date">
                          {formatDateTime(rf.created_at)} • {rf.refund_method?.toUpperCase()}
                          {rf.reason ? ` • ${rf.reason}` : ''}
                        </span>
                        <span style={{ fontSize: '11px', color: '#64748B', marginTop: '2px' }}>
                          Items: {(rf.items || []).map((ri: any) => `${ri.product_name} (×${ri.quantity})`).join(', ')}
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
            <div className="apt-modal-footer" style={{ display: 'flex', gap: '10px' }}>
              <button
                type="button"
                className="apt-modal-refund-btn"
                onClick={() => setShowRefundModal(true)}
                disabled={detailAppointment.refund_status === 'full'}
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px',
                  padding: '12px',
                  backgroundColor: detailAppointment.refund_status === 'full' ? '#F1F5F9' : '#E11D48',
                  color: detailAppointment.refund_status === 'full' ? '#94A3B8' : '#ffffff',
                  border: 'none',
                  borderRadius: '10px',
                  fontSize: '13px',
                  fontWeight: 600,
                  cursor: detailAppointment.refund_status === 'full' ? 'not-allowed' : 'pointer',
                  transition: 'all 0.15s ease',
                }}
              >
                <RotateCcw size={15} />
                <span>
                  {detailAppointment.refund_status === 'full' ? 'Fully Refunded' : 'Refund'}
                </span>
              </button>

              <button
                type="button"
                className="apt-modal-close-btn"
                onClick={() => setDetailAppointment(null)}
                style={{ flex: 1 }}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── 7. Refund Modal Popup ──────────────────────────── */}
      {showRefundModal && detailAppointment && (
        <RefundModal
          isOpen={showRefundModal}
          onClose={() => setShowRefundModal(false)}
          type="appointment"
          transaction={detailAppointment}
          onRefundSuccess={handleRefundSuccess}
        />
      )}
    </div>
  );
}
