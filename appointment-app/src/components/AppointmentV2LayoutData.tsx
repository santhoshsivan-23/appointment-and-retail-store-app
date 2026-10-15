import { useMemo } from 'react';
import {
  Clock,
  User,
  Briefcase,
  Calendar as CalendarIcon,
  Phone,
  Play,
  ChevronDown,
  ChevronUp,
  ChevronRight,
  CalendarX,
  Plus,
  FileText,
  ArrowRight,
} from 'lucide-react';
import type { Staff } from '../api/staffApi';
import type { Appointment } from '../api/appointmentApi';
import {
  timeToMinutes,
  minutesToTime24,
  formatDatePretty,
  formatTimeSlotLabel,
  getStatusMeta,
  getTodayDateStr,
  generateBusinessSlots,
  type BusinessSlot,
} from '../utils/appointmentV2Utils';

export interface AppointmentV2LayoutDataProps {
  isLoadingAppts: boolean;
  viewMode: 'list' | 'grid' | 'time';
  selectedStaff: Staff;
  selectedDate: string;
  appointments: Appointment[];
  businessSlots: BusinessSlot[];
  slotAppointmentMap: Map<string, Appointment[]>;
  expandedApptId: number | null;
  onToggleExpandAppt: (id: number) => void;
  timeFormat: '12' | '24';
  nowMinutes: number;
  onStartServiceClick: (appt: Appointment) => void;
  onContinueServiceClick: (appt: Appointment) => void;
  onOpenDetailsModal: (appt: Appointment) => void;
  onOpenAddModal: (prefilledSlot?: { start24: string; end24: string } | null) => void;
  onSelectToday: () => void;
}

export default function AppointmentV2LayoutData({
  isLoadingAppts,
  viewMode,
  selectedStaff,
  selectedDate,
  appointments,
  businessSlots,
  slotAppointmentMap: _slotAppointmentMap,
  expandedApptId,
  onToggleExpandAppt,
  timeFormat,
  nowMinutes,
  onStartServiceClick,
  onContinueServiceClick,
  onOpenDetailsModal,
  onOpenAddModal,
  onSelectToday,
}: AppointmentV2LayoutDataProps) {
  const formatTime12Leading = (time24: string): string => {
    if (!time24) return '--:--';
    const mins = timeToMinutes(time24);
    const h24 = Math.floor(mins / 60) % 24;
    const m = mins % 60;
    if (timeFormat === '24') {
      return `${String(h24).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
    }
    const period = h24 >= 12 ? 'PM' : 'AM';
    let h12 = h24 % 12;
    if (h12 === 0) h12 = 12;
    return `${String(h12).padStart(2, '0')}:${String(m).padStart(2, '0')} ${period}`;
  };

  const formatSlotRangeLeading = (start24: string, end24: string): string => {
    return `${formatTime12Leading(start24)} - ${formatTime12Leading(end24)}`;
  };

  const slotInterval = 30; // 30 mins per grid row
  const SLOT_HEIGHT = 76; // px per slot row

  // Determine effective grid slots from businessSlots or expand if appointments exist outside standard hours
  const gridSlots: BusinessSlot[] = useMemo(() => {
    if (!businessSlots || businessSlots.length === 0) {
      return generateBusinessSlots('08:00', '20:00', slotInterval);
    }
    let minM = businessSlots[0].startM;
    let maxM = businessSlots[businessSlots.length - 1].endM;

    appointments.forEach((a) => {
      if (a.start_time) {
        const sM = timeToMinutes(a.start_time);
        minM = Math.min(minM, Math.floor(sM / slotInterval) * slotInterval);
      }
      if (a.end_time) {
        const eM = timeToMinutes(a.end_time);
        maxM = Math.max(maxM, Math.ceil(eM / slotInterval) * slotInterval);
      }
    });

    if (minM < businessSlots[0].startM || maxM > businessSlots[businessSlots.length - 1].endM) {
      return generateBusinessSlots(minutesToTime24(minM), minutesToTime24(maxM), slotInterval);
    }
    return businessSlots;
  }, [businessSlots, appointments]);

  // Compute exact multi-slot grid spanning and packing for appointments
  const { apptItems, occupiedSlots } = useMemo(() => {
    if (gridSlots.length === 0) {
      return { apptItems: [], occupiedSlots: new Set<number>() };
    }

    const baseStartM = gridSlots[0].startM;
    const totalSlots = gridSlots.length;
    const occupiedSlots = new Set<number>();

    // Filter valid appointments
    const validAppts = appointments
      .filter((a) => a.start_time && a.end_time)
      .map((a) => {
        const sM = timeToMinutes(a.start_time);
        let eM = timeToMinutes(a.end_time);
        if (eM <= sM) eM = sM + slotInterval;
        return {
          appt: a,
          startM: sM,
          endM: eM,
        };
      })
      .sort((a, b) => a.startM - b.startM || (b.endM - b.startM) - (a.endM - a.startM));

    // Detect overlapping clusters to support side-by-side columns if needed
    const clusters: Array<typeof validAppts> = [];
    let currentCluster: typeof validAppts = [];
    let clusterEndM = -1;

    validAppts.forEach((item) => {
      if (currentCluster.length === 0 || item.startM < clusterEndM) {
        currentCluster.push(item);
        clusterEndM = Math.max(clusterEndM, item.endM);
      } else {
        clusters.push(currentCluster);
        currentCluster = [item];
        clusterEndM = item.endM;
      }
    });
    if (currentCluster.length > 0) {
      clusters.push(currentCluster);
    }

    const apptItems: {
      appt: Appointment;
      startSlotIndex: number;
      endSlotIndex: number;
      spanSlots: number;
      gridRowStart: number;
      gridRowEnd: number;
      colIndex: number;
      totalCols: number;
    }[] = [];

    clusters.forEach((cluster) => {
      const colEndTimes: number[] = [];
      const itemsWithCol: { item: (typeof validAppts)[0]; col: number }[] = [];

      cluster.forEach((item) => {
        let placedCol = -1;
        for (let c = 0; c < colEndTimes.length; c++) {
          if (colEndTimes[c] <= item.startM) {
            placedCol = c;
            colEndTimes[c] = item.endM;
            break;
          }
        }
        if (placedCol === -1) {
          placedCol = colEndTimes.length;
          colEndTimes.push(item.endM);
        }
        itemsWithCol.push({ item, col: placedCol });
      });

      const totalCols = Math.max(1, colEndTimes.length);

      itemsWithCol.forEach(({ item, col }) => {
        const rawStartIndex = Math.floor((item.startM - baseStartM) / slotInterval);
        const rawEndIndex = Math.ceil((item.endM - baseStartM) / slotInterval);

        const startSlotIndex = Math.max(0, Math.min(totalSlots - 1, rawStartIndex));
        const endSlotIndex = Math.max(startSlotIndex + 1, Math.min(totalSlots, rawEndIndex));
        const spanSlots = endSlotIndex - startSlotIndex;

        // Mark all covered slots as occupied
        for (let s = startSlotIndex; s < endSlotIndex; s++) {
          occupiedSlots.add(s);
        }

        apptItems.push({
          appt: item.appt,
          startSlotIndex,
          endSlotIndex,
          spanSlots,
          gridRowStart: startSlotIndex + 1,
          gridRowEnd: endSlotIndex + 1,
          colIndex: col,
          totalCols,
        });
      });
    });

    return { apptItems, occupiedSlots };
  }, [gridSlots, appointments]);

  // Live Red Current Time Indicator calculations across grid
  const isToday = selectedDate === getTodayDateStr();
  const gridStartM = gridSlots.length > 0 ? gridSlots[0].startM : 0;
  const gridEndM = gridSlots.length > 0 ? gridSlots[gridSlots.length - 1].endM : 0;
  const isNowInGrid = isToday && nowMinutes >= gridStartM && nowMinutes <= gridEndM;
  const nowTopPx = isNowInGrid
    ? ((nowMinutes - gridStartM) / slotInterval) * SLOT_HEIGHT
    : 0;

  const renderExpandedDetails = (appt: Appointment, onCollapse?: () => void, hideService = false) => {
    const statusMeta = getStatusMeta(appt.status);
    const svcNames =
      (appt.services || []).map((s) => s.name || s.product_name).join(', ') ||
      'General Service';

    return (
      <div className="v2-details-panel" onClick={(e) => e.stopPropagation()}>
        <div className="v2-details-meta-bar">
          <div className="v2-details-user-group">
            <div className="w-8 h-8 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center font-bold text-xs flex-shrink-0">
              {appt.customer_name ? appt.customer_name[0].toUpperCase() : 'G'}
            </div>
            <div>
              <div className="v2-details-user-name flex items-center gap-1.5">
                <span>{appt.customer_name || 'Walk-in Guest'}</span>
                <span
                  className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                    appt.status === 'in_service'
                      ? 'bg-amber-100 text-amber-800'
                      : appt.status === 'completed'
                      ? 'bg-emerald-100 text-emerald-800'
                      : appt.status === 'no_show'
                      ? 'bg-red-100 text-red-800'
                      : appt.status === 'cancelled'
                      ? 'bg-gray-100 text-gray-800'
                      : 'bg-blue-100 text-blue-800'
                  }`}
                >
                  {statusMeta.label}
                </span>
              </div>
              {appt.customer_phone && (
                <span className="v2-details-user-phone">
                  <Phone size={11} className="text-slate-400" />
                  <span>{appt.customer_phone}</span>
                </span>
              )}
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10.5px] text-slate-400 block font-semibold uppercase">
              Total Amount
            </span>
            <span className="text-sm font-extrabold text-slate-900">
              ${Number(appt.total_amount || 0).toFixed(2)}
            </span>
          </div>
        </div>

        <div className="v2-details-grid">
          {!hideService && (
            <div className="v2-details-cell">
              <span className="v2-details-cell-label">
                <Briefcase size={12} className="text-emerald-600" />
                Service
              </span>
              <span className="v2-details-cell-val" title={svcNames}>
                {svcNames}
              </span>
            </div>
          )}

          <div className="v2-details-cell">
            <span className="v2-details-cell-label">
              <CalendarIcon size={12} className="text-blue-600" />
              Date
            </span>
            <span className="v2-details-cell-val">
              {formatDatePretty(appt.appointment_date || selectedDate)}
            </span>
          </div>

          <div className="v2-details-cell">
            <span className="v2-details-cell-label">
              <Clock size={12} className="text-amber-600" />
              Time Slot
            </span>
            <span className="v2-details-cell-val">
              {formatTimeSlotLabel(appt.start_time, appt.end_time, timeFormat)}
            </span>
          </div>

          <div className="v2-details-cell">
            <span className="v2-details-cell-label">
              <User size={12} className="text-purple-600" />
              Staff
            </span>
            <span className="v2-details-cell-val">
              {appt.staff_name || selectedStaff.name}
            </span>
          </div>

          <div className="v2-details-cell">
            <span className="v2-details-cell-label">
              <Phone size={12} className="text-teal-600" />
              Phone
            </span>
            <span className="v2-details-cell-val">
              {appt.customer_phone || 'None'}
            </span>
          </div>
        </div>

        {appt.notes && (
          <div className="v2-details-notes-box">
            <FileText size={13} className="text-slate-400 flex-shrink-0 mt-0.5" />
            <span className="italic">{appt.notes}</span>
          </div>
        )}

        <div className="v2-details-actions-bar">
          <div className="flex items-center gap-2">
            {appt.status === 'booked' && (
              <button
                type="button"
                className="v2-action-btn v2-action-btn--primary"
                onClick={() => onStartServiceClick(appt)}
              >
                <Play size={12} />
                <span>Start Service</span>
              </button>
            )}

            {appt.status === 'in_service' && (
              <button
                type="button"
                className="v2-action-btn v2-action-btn--continue"
                onClick={() => onContinueServiceClick(appt)}
              >
                <ArrowRight size={12} />
                <span>Continue Service</span>
              </button>
            )}

            <button
              type="button"
              className="v2-action-btn v2-action-btn--outline"
              onClick={() => onOpenDetailsModal(appt)}
            >
              <span>Full Details</span>
              <ChevronRight size={12} />
            </button>
          </div>

          {onCollapse && (
            <button
              type="button"
              className="text-xs text-slate-500 hover:text-slate-800 flex items-center gap-1 font-semibold px-2 py-1 rounded hover:bg-slate-100 transition"
              onClick={onCollapse}
            >
              <ChevronUp size={13} />
              <span>Collapse</span>
            </button>
          )}
        </div>
      </div>
    );
  };

  const renderNoAppointmentsEmptyState = () => (
    <div
      className="v2-empty-schedule-card"
      data-purpose="empty-appointments-state"
    >
      {/* Availability Status Badge */}
      <div className="v2-empty-schedule-card__badge">
        <span className="v2-empty-schedule-card__badge-dot" />
        <span>100% Free Schedule</span>
      </div>

      {/* Modern Gradient Icon Badge */}
      <div className="v2-empty-schedule-card__icon-wrap">
        <CalendarX size={34} strokeWidth={2.2} />
      </div>

      {/* Heading */}
      <h3 className="v2-empty-schedule-card__title">
        No Appointments Booked
      </h3>

      {/* Description */}
      <p className="v2-empty-schedule-card__desc">
        There are currently no appointments booked for{' '}
        <strong style={{ color: '#0f172a', fontWeight: 700 }}>{selectedStaff.name}</strong> on{' '}
        <strong style={{ color: '#0f172a', fontWeight: 700 }}>{formatDatePretty(selectedDate)}</strong>.
      </p>

      {/* Context Meta Box */}
      <div className="v2-empty-schedule-card__meta-box">
        <span className="v2-empty-schedule-card__meta-item">
          <User size={13} style={{ color: '#2563eb' }} />
          <span>Specialist: <strong>{selectedStaff.name}</strong></span>
        </span>
        <span className="v2-empty-schedule-card__meta-dot">•</span>
        <span className="v2-empty-schedule-card__meta-item">
          <CalendarIcon size={13} style={{ color: '#2563eb' }} />
          <span>{formatDatePretty(selectedDate)}</span>
        </span>
        <span className="v2-empty-schedule-card__meta-dot">•</span>
        <span className="v2-empty-schedule-card__meta-item">
          <Clock size={13} style={{ color: '#16a34a' }} />
          <span>All Slots Available</span>
        </span>
      </div>

      {/* Action Buttons */}
      <div className="v2-empty-schedule-card__actions">
        <button
          type="button"
          className="v2-empty-schedule-card__btn-primary"
          onClick={() => onOpenAddModal(null)}
        >
          <Plus size={16} strokeWidth={2.5} />
          <span>Book An Appointment</span>
        </button>
        {selectedDate !== getTodayDateStr() && (
          <button
            type="button"
            className="v2-empty-schedule-card__btn-secondary"
            onClick={onSelectToday}
          >
            <CalendarIcon size={14} style={{ color: '#64748b' }} />
            <span>Go to Today</span>
          </button>
        )}
      </div>

      {/* Subtle Tip */}
      <div className="v2-empty-schedule-card__footer-tip">
        <span>💡 Switch to Time Layout to view all available 30-minute time slots</span>
      </div>
    </div>
  );

  return (
    <section
      className="appointment-v2-left-pane block h-full min-h-0 overflow-y-auto pr-2 pb-6 v2-custom-scroll"
      data-purpose="schedule-slots-list"
      tabIndex={0}
      style={{ outline: 'none' }}
    >
      {isLoadingAppts ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center flex flex-col items-center justify-center">
          <div className="v2-spinner mb-3" />
          <span className="text-sm font-medium text-slate-500">
            Loading schedule for {selectedStaff.name}...
          </span>
        </div>
      ) : viewMode === 'list' ? (
        /* ── VIEW 1: LIST VIEW (CREATED APPOINTMENTS ONLY) ── */
        appointments.length === 0 ? (
          renderNoAppointmentsEmptyState()
        ) : (
          <div className="flex flex-col gap-3">
            {appointments.map((appt) => {
              const isExpanded = expandedApptId === appt.id;
              const isService = appt.status === 'in_service';
              const isCompleted = appt.status === 'completed';
              const statusMeta = getStatusMeta(appt.status);

              return (
                <article
                  key={appt.id}
                  id={`v2-appt-${appt.id}`}
                  className={`v2-list-slot-card ${
                    isService
                      ? 'v2-list-slot-card--in-service'
                      : isCompleted
                      ? 'v2-list-slot-card--completed'
                      : 'v2-list-slot-card--booked'
                  }`}
                >
                  <div
                    className="v2-list-slot-main-row cursor-pointer"
                    onClick={() => onToggleExpandAppt(appt.id)}
                  >
                    {/* Left: Time & Status */}
                    <div className="v2-list-slot-left">
                      <span className="v2-list-time-pill">
                        <Clock size={13} style={{ color: statusMeta.color }} />
                        <span>{formatSlotRangeLeading(appt.start_time, appt.end_time)}</span>
                      </span>
                      <span
                        className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                          isService
                            ? 'bg-amber-50 text-amber-700 border border-amber-200'
                            : isCompleted
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : appt.status === 'no_show'
                            ? 'bg-red-50 text-red-700 border border-red-200'
                            : appt.status === 'cancelled'
                            ? 'bg-gray-100 text-gray-700 border border-gray-300'
                            : 'bg-blue-50 text-blue-700 border border-blue-200'
                        }`}
                      >
                        {statusMeta.label}
                      </span>
                    </div>

                    {/* Center: Customer Name Only */}
                    <div className="v2-list-slot-center">
                      <div className="v2-list-customer-info">
                        <User size={14} className="text-slate-400 flex-shrink-0" />
                        <span className="font-bold text-sm text-slate-900 truncate">
                          {appt.customer_name || 'Walk-in Guest'}
                        </span>
                      </div>
                    </div>

                    {/* Right: Total Amount & Dropdown Chevron */}
                    <div className="v2-list-slot-right">
                      <span className="v2-list-amount">
                        ${Number(appt.total_amount || 0).toFixed(2)}
                      </span>

                      <button
                        type="button"
                        className="v2-list-expand-btn"
                        aria-label={isExpanded ? 'Collapse appointment' : 'Expand appointment'}
                        onClick={(e) => {
                          e.stopPropagation();
                          onToggleExpandAppt(appt.id);
                        }}
                      >
                        <ChevronDown
                          size={16}
                          className={`transform transition-transform duration-200 ${isExpanded ? 'rotate-180 text-blue-600' : 'text-slate-400'}`}
                        />
                      </button>
                    </div>
                  </div>

                  {/* Smooth Expand/Collapse Panel */}
                  <div className={`v2-smooth-expand ${isExpanded ? 'v2-smooth-expand--open' : ''}`}>
                    <div className="v2-smooth-expand-content">
                      {renderExpandedDetails(appt, () => onToggleExpandAppt(appt.id), false)}
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
        )
      ) : viewMode === 'grid' ? (
        /* ── VIEW 2: GRID VIEW (RESPONSIVE 4-COLUMN CARDS WITH POPUP MODAL) ── */
        appointments.length === 0 ? (
          renderNoAppointmentsEmptyState()
        ) : (
          <div className="v2-grid-view">
            {appointments.map((appt) => {
              const statusMeta = getStatusMeta(appt.status);
              const servicesStr =
                (appt.services || []).map((s) => s.name || s.product_name).join(', ') ||
                'General Service';

              return (
                <article
                  key={appt.id}
                  className={`v2-grid-card v2-grid-card--${appt.status || 'booked'}`}
                  onClick={() => onOpenDetailsModal(appt)}
                  title="Click to view appointment details"
                >
                  <div className="v2-grid-card__header">
                    <div className="v2-grid-card__time">
                      <Clock
                        size={13}
                        style={{ color: statusMeta.color }}
                        className={`v2-grid-card__time-icon v2-grid-card__time-icon--${appt.status || 'booked'} flex-shrink-0`}
                      />
                      <span>
                        {formatSlotRangeLeading(appt.start_time, appt.end_time)}
                      </span>
                    </div>
                    <span
                      className={`v2-grid-card__status-badge v2-grid-card__status-badge--${
                        appt.status || 'booked'
                      }`}
                    >
                      {statusMeta.label}
                    </span>
                  </div>

                  <div className="v2-grid-card__body">
                    <div className="v2-grid-card__customer" title={appt.customer_name || 'Walk-in Guest'}>
                      <User size={13} className="text-slate-400 flex-shrink-0" />
                      <span className="truncate">{appt.customer_name || 'Walk-in Guest'}</span>
                    </div>
                    <div className="v2-grid-card__service" title={servicesStr}>
                      <Briefcase size={12} className="text-emerald-600 flex-shrink-0" />
                      <span className="truncate">{servicesStr}</span>
                    </div>
                    {appt.customer_phone ? (
                      <div className="v2-grid-card__phone" title={appt.customer_phone}>
                        <Phone size={11} className="text-slate-400 flex-shrink-0" />
                        <span className="truncate">{appt.customer_phone}</span>
                      </div>
                    ) : null}
                  </div>

                  <div className="v2-grid-card__footer">
                    <span className="v2-grid-card__amount">
                      ${Number(appt.total_amount || 0).toFixed(2)}
                    </span>
                    <span className="v2-grid-card__cta">
                      <span>View Details</span>
                      <ChevronRight size={13} />
                    </span>
                  </div>
                </article>
              );
            })}
          </div>
        )
      ) : (
        /* ── VIEW 3: TIME VIEW (EXACT REFERENCE IMAGE SCHEDULE DESIGN) ── */
        <div
          className="v2-timeline-board"
          data-purpose="timeline-schedule-view"
          style={{
            gridTemplateRows: `repeat(${gridSlots.length}, minmax(${SLOT_HEIGHT}px, auto))`,
          }}
        >
          {/* Column 1: Time Labels for each slot (Always visible, never skipped) */}
          {gridSlots.map((slot, index) => (
            <div
              key={`time-${slot.start24}`}
              id={`v2-time-label-${slot.start24}`}
              className="v2-timeline-time-col"
              style={{
                gridColumn: 1,
                gridRow: index + 1,
              }}
            >
              <span>{formatTime12Leading(slot.start24)}</span>
            </div>
          ))}

          {/* Column 2: Available Empty Slots (for slots without an appointment) */}
          {gridSlots.map((slot, index) => {
            if (occupiedSlots.has(index)) return null;

            return (
              <div
                key={`empty-${slot.start24}`}
                id={`v2-empty-slot-${slot.start24}`}
                className="v2-timeline-empty-slot"
                style={{
                  gridColumn: 2,
                  gridRow: index + 1,
                }}
                onClick={() => {
                  onOpenAddModal({
                    start24: slot.start24,
                    end24: slot.end24,
                  });
                }}
                title={`Book slot: ${formatSlotRangeLeading(slot.start24, slot.end24)}`}
              >
                <span className="v2-timeline-empty-btn">
                  <Plus size={13} />
                  <span>Book Slot</span>
                </span>
              </div>
            );
          })}

          {/* Column 2: Appointment Cards Spanning Exact Multi-Slot Durations */}
          {apptItems.map((item) => {
            const appt = item.appt;
            const isExpanded = expandedApptId === appt.id;
            const statusMeta = getStatusMeta(appt.status);
            const servicesStr =
              (appt.services || []).map((s) => s.name || s.product_name).join(', ') ||
              'General Consultation / Service';

            return (
              <article
                key={appt.id}
                id={`v2-timeline-appt-${appt.id}`}
                className={`v2-timeline-card v2-timeline-card--${statusMeta.key} ${
                  isExpanded ? 'v2-timeline-card--expanded' : ''
                }`}
                style={{
                  gridColumn: 2,
                  gridRow: `${item.gridRowStart} / ${item.gridRowEnd}`,
                  width:
                    item.totalCols > 1
                      ? `calc(${100 / item.totalCols}% - 12px)`
                      : 'calc(100% - 16px)',
                  marginLeft:
                    item.totalCols > 1
                      ? `calc(${(item.colIndex * 100) / item.totalCols}% + 6px)`
                      : '8px',
                  zIndex: 10 + item.colIndex,
                }}
                onClick={() => onToggleExpandAppt(appt.id)}
              >
                {/* Left Colored Accent Pill Bar */}
                <div
                  className={`v2-timeline-card__accent-bar v2-timeline-card__accent-bar--${statusMeta.key}`}
                />

                <div className="v2-timeline-card__inner">
                  {/* Top Header: Time range + Status badge */}
                  <div className="v2-timeline-card-header">
                    <div className="v2-timeline-time-info">
                      <Clock size={13} className="v2-timeline-clock-icon" />
                      <span>{formatSlotRangeLeading(appt.start_time, appt.end_time)}</span>
                    </div>
                    <span className={`v2-timeline-badge v2-timeline-badge--${statusMeta.key}`}>
                      {statusMeta.label.toUpperCase()}
                    </span>
                  </div>

                  {/* Customer Name */}
                  <div
                    className="v2-timeline-cust-name"
                    title={appt.customer_name || 'Walk-in Guest'}
                  >
                    {appt.customer_name || 'Walk-in Guest'}
                  </div>

                  {/* Service Line (visible when multi-slot or expanded) */}
                  {(item.spanSlots >= 2 || isExpanded) && (
                    <div className="v2-timeline-service-name" title={servicesStr}>
                      {servicesStr}
                    </div>
                  )}

                  {/* Bottom Row: Phone Number & Total Amount */}
                  {(item.spanSlots >= 2 || isExpanded) && (
                    <div className="v2-timeline-bottom-row">
                      <span className="v2-timeline-phone">
                        {appt.customer_phone || ''}
                      </span>
                      <span className="v2-timeline-amount">
                        {Number(appt.total_amount || 0) === 0
                          ? '0'
                          : `$${Number(appt.total_amount || 0).toFixed(2)}`}
                      </span>
                    </div>
                  )}

                  {/* Quick Action Buttons for 2hr+ cards (e.g. 1 to 3 clock) */}
                  {item.spanSlots >= 3 && !isExpanded && (
                    <div
                      className="v2-timeline-quick-actions"
                      onClick={(e) => e.stopPropagation()}
                    >
                      {appt.status === 'booked' && (
                        <button
                          type="button"
                          className="v2-timeline-quick-btn v2-timeline-quick-btn--start"
                          onClick={() => onStartServiceClick(appt)}
                        >
                          <Play size={11} />
                          <span>Start Service</span>
                        </button>
                      )}
                      {appt.status === 'in_service' && (
                        <button
                          type="button"
                          className="v2-timeline-quick-btn v2-timeline-quick-btn--continue"
                          onClick={() => onContinueServiceClick(appt)}
                        >
                          <ArrowRight size={11} />
                          <span>Continue</span>
                        </button>
                      )}
                      <button
                        type="button"
                        className="v2-timeline-quick-btn v2-timeline-quick-btn--details"
                        onClick={() => onOpenDetailsModal(appt)}
                      >
                        <span>Full Details</span>
                        <ChevronRight size={11} />
                      </button>
                    </div>
                  )}

                  {/* Smooth Expand/Collapse Details */}
                  <div className={`v2-smooth-expand ${isExpanded ? 'v2-smooth-expand--open' : ''}`}>
                    <div className="v2-smooth-expand-content">
                      {renderExpandedDetails(appt, () => onToggleExpandAppt(appt.id))}
                    </div>
                  </div>
                </div>
              </article>
            );
          })}

          {/* Live Red Current Time Indicator Line & Circular Pin Dot */}
          {isNowInGrid && (
            <>
              <div
                className="v2-timeline-now-line"
                style={{ top: `${nowTopPx}px` }}
              />
              <div
                className="v2-timeline-now-dot"
                style={{ top: `${nowTopPx}px` }}
              />
            </>
          )}
        </div>
      )}
    </section>
  );
}
