import { useState, useEffect, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import {
  RotateCw,
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
  BadgeCheck,
  Clock,
  ShieldCheck,
  History,
} from 'lucide-react';
import { appointmentApi, type Appointment } from '../api/appointmentApi';
import { staffApi, type Staff } from '../api/staffApi';
import '../styles/appointment_history.css';

const PAGE_SIZE = 20;

/* ── Safe Currency Formatter ───────────────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
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

  return {
    ...a,
    total_amount: Number(a.total_amount) || 0,
    services: parsedServices,
    customer_name: a.customer_name || 'Walk-in Customer',
    customer_phone: a.customer_phone || '',
    staff_name: a.staff_name || '',
    notes: a.notes || '',
  };
};

export default function AppointmentHistoryView() {
  /* ── State ────────────────────────────────────────────── */
  const [allAppointments, setAllAppointments] = useState<Appointment[]>([]);
  const [displayAppointments, setDisplayAppointments] = useState<Appointment[]>([]);
  const [staffList, setStaffList] = useState<Staff[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSearching, setIsSearching] = useState<boolean>(false);

  const [searchInput, setSearchInput] = useState<string>('');
  const [activeSearchQuery, setActiveSearchQuery] = useState<string>('');
  const [isPanelExpanded, setIsPanelExpanded] = useState<boolean>(true);
  const [currentPage, setCurrentPage] = useState<number>(1);
  const [detailAppointment, setDetailAppointment] = useState<Appointment | null>(null);

  /* ── Sort & Filter Completed Appointments Helper ─────── */
  const processList = (rawList: any[]): Appointment[] => {
    // STRICTLY DISPLAY ONLY COMPLETED / PERFORMED APPOINTMENTS
    const completed = rawList
      .map(normalizeAppointment)
      .filter((a) => {
        const s = (a.status || '').toLowerCase().trim();
        return s === 'completed' || s === 'performed';
      });

    // Sort newest first by date and startTime
    completed.sort((a, b) => {
      const cmp = (b.appointment_date || '').localeCompare(a.appointment_date || '');
      if (cmp !== 0) return cmp;
      return (b.start_time || '').localeCompare(a.start_time || '');
    });

    return completed;
  };

  /* ── Load History ─────────────────────────────────────── */
  const loadHistory = useCallback(async () => {
    setIsLoading(true);
    try {
      const [aptRes, staffRes] = await Promise.all([
        appointmentApi.getAppointments({ status: 'completed' }),
        staffApi.getAll(true),
      ]);

      const apts = processList(aptRes.data?.data ?? []);
      setAllAppointments(apts);
      setDisplayAppointments(apts);
      setStaffList(staffRes.data?.data ?? []);
      setCurrentPage(1);
      setActiveSearchQuery('');
      setSearchInput('');
    } catch (err) {
      console.error('Error loading appointment history:', err);
      toast.error('Failed to load appointment history');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadHistory();
  }, [loadHistory]);

  /* ── Search Handlers ──────────────────────────────────── */
  const handlePerformSearch = async () => {
    const query = searchInput.trim();
    setIsSearching(true);
    setActiveSearchQuery(query);
    try {
      const res = await appointmentApi.getAppointments({
        search: query.length > 0 ? query : undefined,
        status: 'completed',
      });
      const apts = processList(res.data?.data ?? []);
      setDisplayAppointments(apts);
      setCurrentPage(1);
    } catch (err) {
      console.error('Error searching appointment history:', err);
      toast.error('Error searching appointments');
    } finally {
      setIsSearching(false);
    }
  };

  const handleResetSearch = () => {
    setSearchInput('');
    setActiveSearchQuery('');
    setDisplayAppointments(allAppointments);
    setCurrentPage(1);
  };

  /* ── Metrics ──────────────────────────────────────────── */
  const todayStr = useMemo(() => {
    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }, []);

  const totalPerformedCount = allAppointments.length;

  const todayPerformedCount = useMemo(() => {
    return allAppointments.filter((a) => a.appointment_date === todayStr).length;
  }, [allAppointments, todayStr]);

  const totalRevenue = useMemo(() => {
    return allAppointments.reduce(
      (sum, a) => sum + (typeof a.total_amount === 'number' ? a.total_amount : parseFloat(String(a.total_amount)) || 0),
      0
    );
  }, [allAppointments]);

  /* ── Pagination ───────────────────────────────────────── */
  const totalItems = displayAppointments.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / PAGE_SIZE));
  const validPage = Math.min(Math.max(1, currentPage), totalPages);

  const paginatedList = useMemo(() => {
    const start = (validPage - 1) * PAGE_SIZE;
    return displayAppointments.slice(start, start + PAGE_SIZE);
  }, [displayAppointments, validPage]);

  const startItem = totalItems === 0 ? 0 : (validPage - 1) * PAGE_SIZE + 1;
  const endItem = Math.min(validPage * PAGE_SIZE, totalItems);

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
              {allAppointments.length} Performed
            </div>
          </div>

          <div className="apt-main-card__header-right">
            <button
              type="button"
              className="apt-refresh-btn"
              onClick={(e) => {
                e.stopPropagation();
                loadHistory();
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

        {/* Collapsible Content: 3 KPI Cards + Search & Apply Filter Bar */}
        <div className={`apt-main-card__collapsible ${!isPanelExpanded ? 'apt-main-card__collapsible--collapsed' : ''}`}>
          <div className="apt-main-card__collapsible-inner">
            {/* 2. Compact KPI Metrics Summary */}
            <div className="apt-metrics-row">
              {/* Total Performed */}
              <div className="apt-metric-card">
                <div className="apt-metric-icon" style={{ background: '#ECFDF5', color: '#10B981' }}>
                  <CheckCircle2 size={18} />
                </div>
                <div className="apt-metric-info">
                  <div className="apt-metric-title">Total Performed</div>
                  <div className="apt-metric-value">{totalPerformedCount} Appointments</div>
                  <div className="apt-metric-sub">100% completed &amp; fulfilled</div>
                </div>
              </div>

              {/* Performed Today */}
              <div className="apt-metric-card">
                <div className="apt-metric-icon" style={{ background: '#F0F9FF', color: '#0EA5E9' }}>
                  <Calendar size={18} />
                </div>
                <div className="apt-metric-info">
                  <div className="apt-metric-title">Performed Today</div>
                  <div className="apt-metric-value">{todayPerformedCount} Completed</div>
                  <div className="apt-metric-sub">Sessions served today</div>
                </div>
              </div>

              {/* Service Revenue */}
              <div className="apt-metric-card">
                <div className="apt-metric-icon" style={{ background: '#F5F3FF', color: '#8B5CF6' }}>
                  <DollarSign size={18} />
                </div>
                <div className="apt-metric-info">
                  <div className="apt-metric-title">Service Revenue</div>
                  <div className="apt-metric-value">${fmtMoney(totalRevenue)}</div>
                  <div className="apt-metric-sub">Total earned from performed sessions</div>
                </div>
              </div>
            </div>

            {/* 3. Search Bar & Audit Banner */}
            <div className="apt-search-bar">
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
              onClick={loadHistory}
            >
              <RotateCw size={15} />
              <span>Reload History</span>
            </button>
          </div>
        ) : (
          <div className="apt-history-list">
            {paginatedList.map((a) => (
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
                    <User size={15} style={{ color: '#94A3B8' }} />
                    <span>{a.customer_name || 'Walk-in Customer'}</span>
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
                </div>

                {/* 3. Total Amount & Chevron */}
                <div className="apt-card-right">
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
            Showing {startItem} - {endItem} of {totalItems} records (Page {validPage} of {totalPages})
          </div>

          <div className="apt-pagination-actions">
            <button
              type="button"
              className="apt-page-nav-btn"
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              disabled={validPage <= 1}
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
                  className={`apt-page-num-btn ${p === validPage ? 'apt-page-num-btn--active' : ''}`}
                  onClick={() => setCurrentPage(p)}
                >
                  {p}
                </button>
              ))
            ) : (
              <>
                <button
                  type="button"
                  className={`apt-page-num-btn ${validPage === 1 ? 'apt-page-num-btn--active' : ''}`}
                  onClick={() => setCurrentPage(1)}
                >
                  1
                </button>
                {validPage > 3 && <span className="apt-page-ellipsis">...</span>}
                {Array.from(
                  { length: 3 },
                  (_, i) => Math.max(2, Math.min(totalPages - 1, validPage - 1 + i))
                )
                  .filter((v, idx, arr) => arr.indexOf(v) === idx && v > 1 && v < totalPages)
                  .map((p) => (
                    <button
                      key={p}
                      type="button"
                      className={`apt-page-num-btn ${p === validPage ? 'apt-page-num-btn--active' : ''}`}
                      onClick={() => setCurrentPage(p)}
                    >
                      {p}
                    </button>
                  ))}
                {validPage < totalPages - 2 && <span className="apt-page-ellipsis">...</span>}
                <button
                  type="button"
                  className={`apt-page-num-btn ${validPage === totalPages ? 'apt-page-num-btn--active' : ''}`}
                  onClick={() => setCurrentPage(totalPages)}
                >
                  {totalPages}
                </button>
              </>
            )}

            <button
              type="button"
              className="apt-page-nav-btn"
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              disabled={validPage >= totalPages}
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
                <h3 className="apt-modal-title">Appointment Details</h3>
                <div className="apt-modal-apt-no">
                  #APT-{String(detailAppointment.id).padStart(4, '0')}
                </div>
              </div>
              <div className="apt-modal-status-badge">
                <CheckCircle2 size={12} />
                <span>{String(detailAppointment.status).toUpperCase()}</span>
              </div>
            </div>

            <div className="apt-modal-divider" />

            {/* Customer & Staff Info */}
            <div className="apt-modal-grid-2">
              <div>
                <div className="apt-modal-field-label">Customer</div>
                <div className="apt-modal-field-val">
                  {detailAppointment.customer_name || 'Walk-in Guest'}
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
                  const sPrice = Number(s.price) || 0;
                  return (
                    <div key={idx} className="apt-modal-service-row">
                      <span className="apt-modal-service-name">{sName}</span>
                      <span className="apt-modal-service-price">${fmtMoney(sPrice)}</span>
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

            {/* Total Amount */}
            <div className="apt-modal-total-row">
              <span className="apt-modal-total-label">Total Amount</span>
              <span className="apt-modal-total-value">
                ${fmtMoney(detailAppointment.total_amount)}
              </span>
            </div>

            {/* Close Button */}
            <button
              type="button"
              className="apt-modal-close-btn"
              onClick={() => setDetailAppointment(null)}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
