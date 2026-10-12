import { useState, useRef, useEffect, useMemo } from 'react';
import { createPortal } from 'react-dom';
import {
  Calendar,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  X,
  Check,
} from 'lucide-react';
import '../styles/date_range_filter.css';

export interface DateRangeFilterProps {
  startDate: string; // 'YYYY-MM-DD'
  endDate: string;   // 'YYYY-MM-DD'
  onChange: (startDate: string, endDate: string) => void;
  className?: string;
}

const formatDateStr = (d: Date): string => {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const formatPrettyWithDay = (dateStr: string): string => {
  if (!dateStr) return '';
  const [y, m, d] = dateStr.split('-').map(Number);
  const dt = new Date(y, m - 1, d);
  const dayName = DAYS[dt.getDay()];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${dayName}, ${months[dt.getMonth()]} ${dt.getDate()}, ${dt.getFullYear()}`;
};

const formatPrettyShortWithDay = (dateStr: string): string => {
  if (!dateStr) return '';
  const [y, m, d] = dateStr.split('-').map(Number);
  const dt = new Date(y, m - 1, d);
  const dayName = DAYS[dt.getDay()];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${dayName}, ${months[dt.getMonth()]} ${dt.getDate()}`;
};

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

export default function DateRangeFilter({
  startDate,
  endDate,
  onChange,
  className = '',
}: DateRangeFilterProps) {
  // Quick dropdown state (small dropdown under button)
  const [isQuickOpen, setIsQuickOpen] = useState(false);
  const quickMenuRef = useRef<HTMLDivElement>(null);

  // Centered Modal Calendar state
  const [isModalOpen, setIsModalOpen] = useState(false);

  // Month & Year scrollable popup state (shows 5 items at a time)
  const [showMonthSelect, setShowMonthSelect] = useState(false);
  const [showYearSelect, setShowYearSelect] = useState(false);
  const monthListRef = useRef<HTMLDivElement>(null);
  const yearListRef = useRef<HTMLDivElement>(null);

  // Staged selection inside modal before clicking Apply
  const [tempStart, setTempStart] = useState<string>(startDate);
  const [tempEnd, setTempEnd] = useState<string>(endDate);
  const [hoverDate, setHoverDate] = useState<string | null>(null);

  // Calendar month & year navigator
  const [viewDate, setViewDate] = useState<Date>(() => {
    if (startDate) {
      const [y, m] = startDate.split('-').map(Number);
      return new Date(y, m - 1, 1);
    }
    return new Date();
  });

  const todayStr = useMemo(() => formatDateStr(new Date()), []);

  // Quick range helpers
  const yesterdayStr = useMemo(() => {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return formatDateStr(d);
  }, []);

  const thisWeekRange = useMemo(() => {
    const d = new Date();
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Monday
    const monday = new Date(d.setDate(diff));
    return { start: formatDateStr(monday), end: todayStr };
  }, [todayStr]);

  const thisMonthRange = useMemo(() => {
    const d = new Date();
    return {
      start: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`,
      end: todayStr,
    };
  }, [todayStr]);

  const lastMonthRange = useMemo(() => {
    const d = new Date();
    d.setMonth(d.getMonth() - 1);
    const start = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`;
    const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
    return { start, end: formatDateStr(lastDay) };
  }, []);

  const getPastNDays = (days: number) => {
    const d = new Date();
    d.setDate(d.getDate() - (days - 1));
    return { start: formatDateStr(d), end: todayStr };
  };

  // Click outside quick dropdown
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (quickMenuRef.current && !quickMenuRef.current.contains(e.target as Node)) {
        setIsQuickOpen(false);
      }
    };
    if (isQuickOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isQuickOpen]);

  // Sync temp dates when modal opens
  const openModal = () => {
    setIsQuickOpen(false);
    setTempStart(startDate || todayStr);
    setTempEnd(endDate || startDate || todayStr);
    setHoverDate(null);
    setShowMonthSelect(false);
    setShowYearSelect(false);
    if (startDate) {
      const [y, m] = startDate.split('-').map(Number);
      setViewDate(new Date(y, m - 1, 1));
    } else {
      setViewDate(new Date());
    }
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setShowMonthSelect(false);
    setShowYearSelect(false);
  };

  // Quick Preset Selection Click
  const handleSelectQuick = (start: string, end: string) => {
    onChange(start, end);
    setIsQuickOpen(false);
  };

  // Trigger button label - displays both date and day
  const triggerLabel = useMemo(() => {
    if (!startDate) return 'Select Date Range';
    if (startDate === todayStr && endDate === todayStr) {
      return `Today · ${formatPrettyWithDay(todayStr)}`;
    }
    if (startDate === yesterdayStr && endDate === yesterdayStr) {
      return `Yesterday · ${formatPrettyWithDay(yesterdayStr)}`;
    }
    if (startDate === thisWeekRange.start && endDate === thisWeekRange.end) {
      return `This Week · ${formatPrettyShortWithDay(thisWeekRange.start)} – ${formatPrettyWithDay(thisWeekRange.end)}`;
    }
    if (startDate === thisMonthRange.start && endDate === thisMonthRange.end) {
      return `This Month · ${formatPrettyShortWithDay(thisMonthRange.start)} – ${formatPrettyWithDay(thisMonthRange.end)}`;
    }
    if (startDate === lastMonthRange.start && endDate === lastMonthRange.end) {
      return `Last Month · ${formatPrettyShortWithDay(lastMonthRange.start)} – ${formatPrettyWithDay(lastMonthRange.end)}`;
    }
    if (startDate === endDate) {
      return formatPrettyWithDay(startDate);
    }
    return `${formatPrettyShortWithDay(startDate)} – ${formatPrettyWithDay(endDate)}`;
  }, [startDate, endDate, todayStr, yesterdayStr, thisWeekRange, thisMonthRange, lastMonthRange]);

  // Calendar calculations
  const year = viewDate.getFullYear();
  const month = viewDate.getMonth();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const firstDayIndex = new Date(year, month, 1).getDay(); // 0 is Sunday (matches S M T W T F S)
  const offsetDays = firstDayIndex; // Sunday first

  // Generate 15 years around current view
  const yearsList = useMemo(() => {
    const list: number[] = [];
    const base = new Date().getFullYear();
    for (let y = base - 7; y <= base + 7; y++) {
      list.push(y);
    }
    return list;
  }, []);

  // Scroll active item into view when popup opens
  useEffect(() => {
    if (showMonthSelect && monthListRef.current) {
      const activeEl = monthListRef.current.querySelector('.date-scroll-item--selected');
      if (activeEl) {
        activeEl.scrollIntoView({ block: 'nearest' });
      }
    }
  }, [showMonthSelect]);

  useEffect(() => {
    if (showYearSelect && yearListRef.current) {
      const activeEl = yearListRef.current.querySelector('.date-scroll-item--selected');
      if (activeEl) {
        activeEl.scrollIntoView({ block: 'nearest' });
      }
    }
  }, [showYearSelect]);

  const handlePrevMonth = () => {
    setViewDate(new Date(year, month - 1, 1));
  };

  const handleNextMonth = () => {
    setViewDate(new Date(year, month + 1, 1));
  };

  const handleDayClick = (dayNum: number) => {
    const d = new Date(year, month, dayNum);
    const dateStr = formatDateStr(d);

    if (!tempStart || (tempStart && tempEnd && tempStart !== tempEnd)) {
      setTempStart(dateStr);
      setTempEnd(dateStr);
    } else {
      if (dateStr < tempStart) {
        setTempStart(dateStr);
        setTempEnd(tempStart);
      } else {
        setTempEnd(dateStr);
      }
    }
    setHoverDate(null);
  };

  const handleApplyModal = () => {
    const finalStart = tempStart || todayStr;
    const finalEnd = tempEnd || finalStart;
    onChange(finalStart, finalEnd);
    closeModal();
  };

  const handleChipPreset = (start: string, end: string) => {
    setTempStart(start);
    setTempEnd(end);
    setHoverDate(null);
    const [y, m] = start.split('-').map(Number);
    setViewDate(new Date(y, m - 1, 1));
  };

  return (
    <div className={`date-filter-root ${className}`} ref={quickMenuRef}>
      {/* ── Trigger Button ──────────────────────────────────── */}
      <button
        type="button"
        className={`date-filter-trigger ${isQuickOpen ? 'date-filter-trigger--active' : ''}`}
        onClick={() => setIsQuickOpen((prev) => !prev)}
        title="Select date range"
        aria-label="Select date range"
      >
        <div className="date-filter-trigger__inner">
          <Calendar size={15} className="date-filter-trigger__icon" />
          <span className="date-filter-trigger__text">{triggerLabel}</span>
        </div>
        <ChevronDown size={14} className="date-filter-trigger__chevron" />
      </button>

      {/* ── Quick Date Selection Dropdown ───────────────────── */}
      {isQuickOpen && (
        <div className="date-quick-dropdown">
          <div className="date-quick-dropdown__header">Quick Date Filter</div>
          <button
            type="button"
            className={`date-quick-item ${startDate === todayStr && endDate === todayStr ? 'date-quick-item--active' : ''}`}
            onClick={() => handleSelectQuick(todayStr, todayStr)}
          >
            <span>Today</span>
            {startDate === todayStr && endDate === todayStr && <Check size={14} />}
          </button>
          <button
            type="button"
            className={`date-quick-item ${startDate === yesterdayStr && endDate === yesterdayStr ? 'date-quick-item--active' : ''}`}
            onClick={() => handleSelectQuick(yesterdayStr, yesterdayStr)}
          >
            <span>Yesterday</span>
            {startDate === yesterdayStr && endDate === yesterdayStr && <Check size={14} />}
          </button>
          <button
            type="button"
            className={`date-quick-item ${startDate === thisWeekRange.start && endDate === thisWeekRange.end ? 'date-quick-item--active' : ''}`}
            onClick={() => handleSelectQuick(thisWeekRange.start, thisWeekRange.end)}
          >
            <span>This Week</span>
            {startDate === thisWeekRange.start && endDate === thisWeekRange.end && <Check size={14} />}
          </button>
          <button
            type="button"
            className={`date-quick-item ${startDate === thisMonthRange.start && endDate === thisMonthRange.end ? 'date-quick-item--active' : ''}`}
            onClick={() => handleSelectQuick(thisMonthRange.start, thisMonthRange.end)}
          >
            <span>This Month</span>
            {startDate === thisMonthRange.start && endDate === thisMonthRange.end && <Check size={14} />}
          </button>
          <button
            type="button"
            className={`date-quick-item ${startDate === lastMonthRange.start && endDate === lastMonthRange.end ? 'date-quick-item--active' : ''}`}
            onClick={() => handleSelectQuick(lastMonthRange.start, lastMonthRange.end)}
          >
            <span>Last Month</span>
            {startDate === lastMonthRange.start && endDate === lastMonthRange.end && <Check size={14} />}
          </button>

          <div className="date-quick-divider" />

          {/* Opens the Neat Centered Modal Calendar */}
          <button
            type="button"
            className="date-quick-item date-quick-item--custom"
            onClick={openModal}
          >
            <Calendar size={14} className="text-rose-500" />
            <span>Custom Date Range...</span>
          </button>
        </div>
      )}

      {/* ── Centered Modal Popup with Blurred Background ────── */}
      {isModalOpen &&
        createPortal(
          <div className="date-modal-overlay" onClick={closeModal}>
            <div
              className="date-modal-card"
              onClick={(e) => e.stopPropagation()}
              role="dialog"
              aria-modal="true"
            >
              {/* Modal Header */}
              <div className="date-modal-header">
                <div className="date-modal-header__left">
                  <div className="date-modal-badge">
                    <Calendar size={18} className="date-modal-badge__icon" />
                  </div>
                  <h3 className="date-modal-title">Select Date Range</h3>
                </div>
                <button
                  type="button"
                  className="date-modal-close-btn"
                  onClick={closeModal}
                  aria-label="Close date range modal"
                >
                  <X size={18} />
                </button>
              </div>

              {/* Quick Preset Chips Row */}
              <div className="date-modal-chips">
                <button
                  type="button"
                  className="date-chip-btn"
                  onClick={() => {
                    const r = getPastNDays(7);
                    handleChipPreset(r.start, r.end);
                  }}
                >
                  7 Days
                </button>
                <button
                  type="button"
                  className="date-chip-btn"
                  onClick={() => {
                    const r = getPastNDays(14);
                    handleChipPreset(r.start, r.end);
                  }}
                >
                  14 Days
                </button>
                <button
                  type="button"
                  className="date-chip-btn"
                  onClick={() => {
                    const r = getPastNDays(30);
                    handleChipPreset(r.start, r.end);
                  }}
                >
                  30 Days
                </button>
                <button
                  type="button"
                  className="date-chip-btn"
                  onClick={() => handleChipPreset(thisMonthRange.start, thisMonthRange.end)}
                >
                  This Month
                </button>
                <button
                  type="button"
                  className="date-chip-btn"
                  onClick={() => {
                    const r = getPastNDays(90);
                    handleChipPreset(r.start, r.end);
                  }}
                >
                  3 Months
                </button>
              </div>

              {/* Calendar Month & Year Navigation */}
              <div className="date-calendar-nav">
                <button
                  type="button"
                  className="date-nav-arrow"
                  onClick={handlePrevMonth}
                  title="Previous month"
                  aria-label="Previous month"
                >
                  <ChevronLeft size={17} />
                </button>

                {/* Month and Year Clickable Selectors */}
                <div className="date-nav-title-group">
                  {/* Month Trigger */}
                  <div className="date-nav-picker-anchor">
                    <button
                      type="button"
                      className={`date-nav-title-btn ${showMonthSelect ? 'date-nav-title-btn--active' : ''}`}
                      onClick={() => {
                        setShowMonthSelect((prev) => !prev);
                        setShowYearSelect(false);
                      }}
                    >
                      <span>{MONTH_NAMES[month]}</span>
                      <ChevronDown size={14} className="opacity-60" />
                    </button>

                    {/* Scrollable Month Popup (5 items visible at a time) */}
                    {showMonthSelect && (
                      <div className="date-scroll-select-popup" ref={monthListRef}>
                        <div className="date-scroll-select-list">
                          {MONTH_NAMES.map((name, idx) => (
                            <button
                              key={name}
                              type="button"
                              className={`date-scroll-item ${idx === month ? 'date-scroll-item--selected' : ''}`}
                              onClick={() => {
                                setViewDate(new Date(year, idx, 1));
                                setShowMonthSelect(false);
                              }}
                            >
                              <span>{name}</span>
                              {idx === month && <Check size={13} />}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>

                  {/* Year Trigger */}
                  <div className="date-nav-picker-anchor">
                    <button
                      type="button"
                      className={`date-nav-title-btn ${showYearSelect ? 'date-nav-title-btn--active' : ''}`}
                      onClick={() => {
                        setShowYearSelect((prev) => !prev);
                        setShowMonthSelect(false);
                      }}
                    >
                      <span>{year}</span>
                      <ChevronDown size={14} className="opacity-60" />
                    </button>

                    {/* Scrollable Year Popup (5 items visible at a time) */}
                    {showYearSelect && (
                      <div className="date-scroll-select-popup date-scroll-select-popup--year" ref={yearListRef}>
                        <div className="date-scroll-select-list">
                          {yearsList.map((y) => (
                            <button
                              key={y}
                              type="button"
                              className={`date-scroll-item ${y === year ? 'date-scroll-item--selected' : ''}`}
                              onClick={() => {
                                setViewDate(new Date(y, month, 1));
                                setShowYearSelect(false);
                              }}
                            >
                              <span>{y}</span>
                              {y === year && <Check size={13} />}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                </div>

                <button
                  type="button"
                  className="date-nav-arrow"
                  onClick={handleNextMonth}
                  title="Next month"
                  aria-label="Next month"
                >
                  <ChevronRight size={17} />
                </button>
              </div>

              {/* Weekdays Row: S M T W T F S (Exact match to image) */}
              <div className="date-weekdays-grid">
                <span>S</span>
                <span>M</span>
                <span>T</span>
                <span>W</span>
                <span>T</span>
                <span>F</span>
                <span>S</span>
              </div>

              {/* Days Grid */}
              <div
                className="date-days-grid"
                onMouseLeave={() => setHoverDate(null)}
              >
                {Array.from({ length: offsetDays }).map((_, i) => (
                  <div key={`blank-${i}`} className="date-cell date-cell--blank" />
                ))}
                {Array.from({ length: daysInMonth }).map((_, i) => {
                  const dayNum = i + 1;
                  const cellDate = `${year}-${String(month + 1).padStart(2, '0')}-${String(dayNum).padStart(2, '0')}`;
                  const isStart = cellDate === tempStart;
                  const isEnd = cellDate === tempEnd;

                  const inRange = (() => {
                    if (tempStart && tempEnd && tempStart !== tempEnd) {
                      return cellDate > tempStart && cellDate < tempEnd;
                    }
                    if (tempStart && hoverDate && tempStart === tempEnd) {
                      const mn = tempStart < hoverDate ? tempStart : hoverDate;
                      const mx = tempStart < hoverDate ? hoverDate : tempStart;
                      return cellDate > mn && cellDate < mx;
                    }
                    return false;
                  })();

                  let cellClass = 'date-cell';
                  if (isStart) cellClass += ' date-cell--start';
                  if (isEnd) cellClass += ' date-cell--end';
                  if (inRange) cellClass += ' date-cell--in-range';

                  return (
                    <button
                      key={`day-${dayNum}`}
                      type="button"
                      className={cellClass}
                      onClick={() => handleDayClick(dayNum)}
                      onMouseEnter={() => {
                        if (tempStart && tempStart === tempEnd) {
                          setHoverDate(cellDate);
                        }
                      }}
                    >
                      {dayNum}
                    </button>
                  );
                })}
              </div>

              {/* Modal Footer (Exact layout matching image) */}
              <div className="date-modal-footer">
                <div className="date-modal-footer__left">
                  <span className="date-modal-footer__caption">SELECTED RANGE</span>
                  <span className="date-modal-footer__value">
                    {tempStart && tempEnd
                      ? tempStart === tempEnd
                        ? formatPrettyWithDay(tempStart)
                        : `${formatPrettyShortWithDay(tempStart)} - ${formatPrettyWithDay(tempEnd)}`
                      : tempStart
                      ? formatPrettyWithDay(tempStart)
                      : 'None'}
                  </span>
                </div>

                <div className="date-modal-footer__right">
                  <button
                    type="button"
                    className="date-modal-cancel-btn"
                    onClick={closeModal}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    className="date-modal-apply-btn"
                    onClick={handleApplyModal}
                  >
                    Apply
                  </button>
                </div>
              </div>
            </div>
          </div>,
          document.body
        )}
    </div>
  );
}
