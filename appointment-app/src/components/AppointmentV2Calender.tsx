import type { Staff } from '../api/staffApi';
import type { Appointment } from '../api/appointmentApi';
import { formatDatePretty, getTodayDateStr } from '../utils/appointmentV2Utils';
import {
  CalendarDays,
  Clock,
  Play,
  CheckCircle2,
  UserX,
  XCircle,
} from 'lucide-react';

export interface AppointmentV2CalenderProps {
  selectedStaff: Staff;
  staffBg: string;
  staffInitials: string;
  selectedDate: string;
  calendarViewDate: Date;
  appointments: Appointment[];
  dayStats: {
    total: number;
    booked: number;
    inService: number;
    completed: number;
    noShow: number;
    cancelled: number;
  };
  onSelectDate: (dateStr: string) => void;
  onChangeCalendarMonth: (date: Date) => void;
  onSwitchStaff: () => void;
}

export default function AppointmentV2Calender({
  selectedStaff,
  staffBg,
  staffInitials,
  selectedDate,
  calendarViewDate,
  appointments,
  dayStats,
  onSelectDate,
  onChangeCalendarMonth,
  onSwitchStaff,
}: AppointmentV2CalenderProps) {
  const todayStr = getTodayDateStr();

  return (
    <aside
      className="appointment-v2-right-pane flex flex-col h-full min-h-0 overflow-y-auto pr-1.5 pb-6 v2-custom-scroll gap-4 flex-shrink-0"
      data-purpose="dashboard-sidebar"
    >
      {/* Widget 1: Monthly Calendar */}
      <section
        className="v2-cal-card flex-shrink-0"
        data-purpose="widget-calendar"
      >
        {/* Calendar Header */}
        <div className="v2-cal-header">
          <h2 className="v2-cal-title">
            {calendarViewDate.toLocaleDateString('en-US', {
              month: 'long',
              year: 'numeric',
            })}
          </h2>
          <div className="v2-cal-nav-group">
            <button
              aria-label="Previous month"
              className="v2-cal-nav-btn"
              type="button"
              onClick={() => {
                const d = new Date(calendarViewDate);
                d.setMonth(d.getMonth() - 1);
                onChangeCalendarMonth(d);
              }}
            >
              <svg
                className="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                viewBox="0 0 24 24"
              >
                <polyline points="15 18 9 12 15 6" />
              </svg>
            </button>
            <button
              className="v2-cal-nav-btn"
              type="button"
              onClick={() => {
                const today = new Date();
                onChangeCalendarMonth(today);
                onSelectDate(todayStr);
              }}
            >
              Today
            </button>
            <button
              aria-label="Next month"
              className="v2-cal-nav-btn"
              type="button"
              onClick={() => {
                const d = new Date(calendarViewDate);
                d.setMonth(d.getMonth() + 1);
                onChangeCalendarMonth(d);
              }}
            >
              <svg
                className="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                viewBox="0 0 24 24"
              >
                <polyline points="9 18 15 12 9 6" />
              </svg>
            </button>
          </div>
        </div>

        {/* Weekday Titles */}
        <div className="v2-cal-weekdays">
          <span className="v2-cal-weekday-label">Su</span>
          <span className="v2-cal-weekday-label">Mo</span>
          <span className="v2-cal-weekday-label">Tu</span>
          <span className="v2-cal-weekday-label">We</span>
          <span className="v2-cal-weekday-label">Th</span>
          <span className="v2-cal-weekday-label">Fr</span>
          <span className="v2-cal-weekday-label">Sa</span>
        </div>

        {/* Calendar Days Grid */}
        <div className="v2-cal-grid">
          {(() => {
            const year = calendarViewDate.getFullYear();
            const month = calendarViewDate.getMonth();
            const firstDayIdx = new Date(year, month, 1).getDay();
            const daysInMonth = new Date(year, month + 1, 0).getDate();
            const daysInPrevMonth = new Date(year, month, 0).getDate();

            const cells = [];
            // Prev month trailing days
            for (let i = firstDayIdx - 1; i >= 0; i--) {
              const dayNum = daysInPrevMonth - i;
              cells.push(
                <div key={`prev-${dayNum}`} className="v2-cal-cell">
                  <button type="button" className="v2-cal-day-btn v2-cal-day-btn--other" disabled>
                    {dayNum}
                  </button>
                </div>
              );
            }

            // Current month days
            for (let d = 1; d <= daysInMonth; d++) {
              const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(
                d
              ).padStart(2, '0')}`;
              const isCurrentDay = dateStr === todayStr;
              const isSelected = dateStr === selectedDate;
              const hasAppts = appointments.some((a) => a.appointment_date === dateStr);

              cells.push(
                <div key={dateStr} className="v2-cal-cell">
                  <button
                    type="button"
                    className={`v2-cal-day-btn ${
                      isSelected
                        ? 'v2-cal-day-btn--selected'
                        : isCurrentDay
                        ? 'v2-cal-day-btn--today'
                        : ''
                    }`}
                    onClick={() => {
                      onSelectDate(dateStr);
                    }}
                  >
                    <span>{d}</span>
                    {hasAppts && (
                      <span
                        className={`v2-cal-appt-dot ${
                          isSelected ? 'bg-white' : 'bg-blue-600'
                        }`}
                      />
                    )}
                  </button>
                </div>
              );
            }

            // Next month trailing days to complete full grid
            const totalSoFar = cells.length;
            const remaining = (7 - (totalSoFar % 7)) % 7;
            const totalSlotsNeeded = totalSoFar + remaining < 35 ? 35 - totalSoFar : remaining;
            for (let n = 1; n <= totalSlotsNeeded; n++) {
              cells.push(
                <div key={`next-${n}`} className="v2-cal-cell">
                  <button type="button" className="v2-cal-day-btn v2-cal-day-btn--other" disabled>
                    {n}
                  </button>
                </div>
              );
            }

            return cells;
          })()}
        </div>
      </section>

      {/* Widget 2: Summary Card (Status Section) */}
      <section
        className="bg-white rounded-2xl border border-sage-200/90 shadow-[0_2px_10px_-4px_rgba(6,78,59,0.05)] p-5 flex-shrink-0"
        data-purpose="widget-summary"
      >
        <h2 className="font-bold text-sm text-gray-900 tracking-tight mb-4">
          Summary for {formatDatePretty(selectedDate)}
        </h2>
        <div className="grid grid-cols-2 gap-3 v2-summary-status-grid">
          {/* Total Appts: Subtle Blue */}
          <div className="v2-summary-stat-card v2-summary-stat-card--total p-3 bg-blue-50/80 border border-blue-200 rounded-xl">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[11px] font-semibold text-blue-700 uppercase tracking-wider block">
                Total Appts
              </span>
              <span className="v2-summary-stat-icon-wrap w-6 h-6 rounded-md bg-blue-100 flex items-center justify-center text-blue-700">
                <CalendarDays size={13} strokeWidth={2.2} />
              </span>
            </div>
            <span className="text-2xl font-bold text-blue-900 leading-none">{dayStats.total}</span>
          </div>

          {/* Booked: Rose Accent */}
          <div className="v2-summary-stat-card v2-summary-stat-card--booked p-3 bg-rose-50/80 border border-rose-200 rounded-xl">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[11px] font-semibold text-rose-700 uppercase tracking-wider block">
                Booked
              </span>
              <span className="v2-summary-stat-icon-wrap w-6 h-6 rounded-md bg-rose-100 flex items-center justify-center text-rose-600">
                <Clock size={13} strokeWidth={2.2} />
              </span>
            </div>
            <span className="text-2xl font-bold text-rose-600 leading-none">{dayStats.booked}</span>
          </div>

          {/* In Service: Warm Amber/Orange */}
          <div className="v2-summary-stat-card v2-summary-stat-card--inservice p-3 bg-amber-50/80 border border-amber-200 rounded-xl">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[11px] font-semibold text-amber-800 uppercase tracking-wider block">
                In Service
              </span>
              <span className="v2-summary-stat-icon-wrap w-6 h-6 rounded-md bg-amber-100 flex items-center justify-center text-amber-700">
                <Play size={13} strokeWidth={2.2} />
              </span>
            </div>
            <span className="text-2xl font-bold text-amber-700 leading-none">{dayStats.inService}</span>
          </div>

          {/* Completed: Green Accent */}
          <div className="v2-summary-stat-card v2-summary-stat-card--completed p-3 bg-emerald-50/80 border border-emerald-200 rounded-xl">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[11px] font-semibold text-emerald-800 uppercase tracking-wider block">
                Completed
              </span>
              <span className="v2-summary-stat-icon-wrap w-6 h-6 rounded-md bg-emerald-100 flex items-center justify-center text-emerald-600">
                <CheckCircle2 size={13} strokeWidth={2.2} />
              </span>
            </div>
            <span className="text-2xl font-bold text-emerald-600 leading-none">{dayStats.completed}</span>
          </div>

          {/* No Show: Red Accent (Requirement 3) */}
          <div className="v2-summary-stat-card v2-summary-stat-card--noshow p-3 bg-red-50/80 border border-red-200 rounded-xl">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[11px] font-semibold text-red-700 uppercase tracking-wider block">
                No Show
              </span>
              <span className="v2-summary-stat-icon-wrap w-6 h-6 rounded-md bg-red-100 flex items-center justify-center text-red-600">
                <UserX size={13} strokeWidth={2.2} />
              </span>
            </div>
            <span className="text-2xl font-bold text-red-700 leading-none">{dayStats.noShow}</span>
          </div>

          {/* Cancelled: Gray Accent (Requirement 4) */}
          <div className="v2-summary-stat-card v2-summary-stat-card--cancelled p-3 bg-slate-50/90 border border-slate-200 rounded-xl">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[11px] font-semibold text-slate-600 uppercase tracking-wider block">
                Cancelled
              </span>
              <span className="v2-summary-stat-icon-wrap w-6 h-6 rounded-md bg-slate-200 flex items-center justify-center text-slate-600">
                <XCircle size={13} strokeWidth={2.2} />
              </span>
            </div>
            <span className="text-2xl font-bold text-slate-700 leading-none">{dayStats.cancelled}</span>
          </div>
        </div>
      </section>

      {/* Widget 3: Staff Profile Card */}
      <section
        className="bg-white rounded-2xl border border-sage-200/90 shadow-[0_2px_10px_-4px_rgba(6,78,59,0.05)] p-4 flex items-center justify-between flex-shrink-0"
        data-purpose="widget-staff-profile"
      >
        <div className="flex items-center gap-3">
          <span
            className="w-10 h-10 rounded-xl text-white font-bold text-base flex items-center justify-center shadow-sm"
            style={{ backgroundColor: staffBg }}
          >
            {staffInitials}
          </span>
          <div>
            <h3 className="font-bold text-sm text-gray-900 leading-tight">
              {selectedStaff.name}
            </h3>
            <p className="text-xs text-gray-500 font-medium">
              {selectedStaff.role || 'Stylist / Clinician'}
            </p>
          </div>
        </div>
        <button
          className="text-xs font-semibold text-blue-600 hover:text-blue-800 transition underline underline-offset-2"
          type="button"
          onClick={onSwitchStaff}
        >
          Change
        </button>
      </section>
    </aside>
  );
}

// Named alias for convenience
export { AppointmentV2Calender as AppointmentV2Calendar };
