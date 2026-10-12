import { useState, useMemo } from 'react';
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  X,
  Check,
  Calendar as CalendarIcon,
} from 'lucide-react';
import { formatDatePretty, getTodayDateStr } from '../utils/appointmentV2Utils';

export interface AppointmentV2MobileDatePickerModalProps {
  isOpen: boolean;
  selectedDate: string; // 'YYYY-MM-DD'
  onClose: () => void;
  onApply: (dateStr: string) => void;
}

export default function AppointmentV2MobileDatePickerModal({
  isOpen,
  selectedDate,
  onClose,
  onApply,
}: AppointmentV2MobileDatePickerModalProps) {
  // Pending selected date in 'YYYY-MM-DD' format - only committed to parent on clicking Apply
  const [pendingDate, setPendingDate] = useState<string>(selectedDate || getTodayDateStr());

  // Current calendar month view navigator
  const [pickerMonth, setPickerMonth] = useState<Date>(() => {
    if (selectedDate && /^\d{4}-\d{2}-\d{2}$/.test(selectedDate)) {
      const [y, m, d] = selectedDate.split('-').map(Number);
      return new Date(y, m - 1, d);
    }
    return new Date();
  });

  const todayStr = getTodayDateStr();

  const year = pickerMonth.getFullYear();
  const month = pickerMonth.getMonth();

  const monthName = pickerMonth.toLocaleDateString('en-US', {
    month: 'long',
    year: 'numeric',
  });

  // Calculate calendar grid days
  const calendarDays = useMemo(() => {
    const firstDayOfWeek = new Date(year, month, 1).getDay(); // 0 = Sun
    const totalDaysInMonth = new Date(year, month + 1, 0).getDate();

    const blanks: (null | number)[] = Array(firstDayOfWeek).fill(null);
    const days: (null | number)[] = Array.from(
      { length: totalDaysInMonth },
      (_, i) => i + 1
    );

    return [...blanks, ...days];
  }, [year, month]);

  if (!isOpen) return null;

  const handlePrevMonth = () => {
    setPickerMonth(new Date(year, month - 1, 1));
  };

  const handleNextMonth = () => {
    setPickerMonth(new Date(year, month + 1, 1));
  };

  const handleSelectToday = () => {
    const today = new Date();
    setPickerMonth(today);
    setPendingDate(todayStr);
  };

  const handleDayClick = (dayNum: number) => {
    const mStr = String(month + 1).padStart(2, '0');
    const dStr = String(dayNum).padStart(2, '0');
    const dateStr = `${year}-${mStr}-${dStr}`;
    setPendingDate(dateStr);
  };

  const handleApply = () => {
    onApply(pendingDate);
  };

  const WEEKDAYS = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  return (
    <div
      className="v2-modal-overlay v2-mobile-datepicker-overlay"
      onClick={onClose}
      style={{ zIndex: 99999 }}
    >
      <div
        className="v2-modal v2-mobile-datepicker-modal"
        onClick={(e) => e.stopPropagation()}
        style={{
          maxWidth: '380px',
          width: '92%',
          borderRadius: '20px',
          overflow: 'hidden',
          backgroundColor: '#ffffff',
          boxShadow: '0 25px 60px -15px rgba(15, 23, 42, 0.3)',
        }}
      >
        {/* Header */}
        <div className="v2-modal__header" style={{ padding: '16px 20px' }}>
          <div className="v2-modal__header-left" style={{ gap: '10px' }}>
            <div
              className="v2-modal__header-icon-badge"
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                backgroundColor: '#eff6ff',
                color: '#2563eb',
              }}
            >
              <CalendarDays size={18} strokeWidth={2.2} />
            </div>
            <div className="v2-modal__header-titles">
              <h3 className="v2-modal__title" style={{ fontSize: '17px' }}>
                Select Date
              </h3>
              <p className="v2-modal__subtitle" style={{ fontSize: '12px' }}>
                Pick a date to view appointments
              </p>
            </div>
          </div>
          <button
            type="button"
            className="v2-modal__close-btn"
            onClick={onClose}
            aria-label="Close date picker"
          >
            <X size={18} />
          </button>
        </div>

        {/* Body: Month Nav & Grid */}
        <div
          className="v2-modal__body"
          style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: '14px' }}
        >
          {/* Month / Year Navigation */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '6px 8px',
              backgroundColor: '#f8fafc',
              borderRadius: '12px',
              border: '1px solid #e2e8f0',
            }}
          >
            <button
              type="button"
              onClick={handlePrevMonth}
              aria-label="Previous month"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                width: '32px',
                height: '32px',
                borderRadius: '8px',
                border: '1px solid #e2e8f0',
                backgroundColor: '#ffffff',
                color: '#334155',
                cursor: 'pointer',
              }}
            >
              <ChevronLeft size={16} />
            </button>

            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontWeight: 700, fontSize: '14.5px', color: '#0f172a' }}>
                {monthName}
              </span>
              <button
                type="button"
                onClick={handleSelectToday}
                style={{
                  fontSize: '11px',
                  fontWeight: 600,
                  padding: '3px 8px',
                  borderRadius: '6px',
                  backgroundColor: '#eff6ff',
                  border: '1px solid #bfdbfe',
                  color: '#1d4ed8',
                  cursor: 'pointer',
                }}
              >
                Today
              </button>
            </div>

            <button
              type="button"
              onClick={handleNextMonth}
              aria-label="Next month"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                width: '32px',
                height: '32px',
                borderRadius: '8px',
                border: '1px solid #e2e8f0',
                backgroundColor: '#ffffff',
                color: '#334155',
                cursor: 'pointer',
              }}
            >
              <ChevronRight size={16} />
            </button>
          </div>

          {/* Weekday Row */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(7, 1fr)',
              textAlign: 'center',
              gap: '4px',
            }}
          >
            {WEEKDAYS.map((w, idx) => (
              <span
                key={idx}
                style={{
                  fontSize: '11.5px',
                  fontWeight: 700,
                  color: idx === 0 ? '#ef4444' : '#64748b',
                  padding: '4px 0',
                }}
              >
                {w}
              </span>
            ))}
          </div>

          {/* Days Grid */}
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(7, 1fr)',
              gap: '6px',
            }}
          >
            {calendarDays.map((dayNum, idx) => {
              if (dayNum === null) {
                return <div key={`blank-${idx}`} style={{ height: '36px' }} />;
              }

              const mStr = String(month + 1).padStart(2, '0');
              const dStr = String(dayNum).padStart(2, '0');
              const dayDateStr = `${year}-${mStr}-${dStr}`;
              const isSelected = dayDateStr === pendingDate;
              const isToday = dayDateStr === todayStr;

              return (
                <button
                  key={`day-${dayNum}`}
                  type="button"
                  onClick={() => handleDayClick(dayNum)}
                  style={{
                    height: '36px',
                    width: '100%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    borderRadius: '10px',
                    fontSize: '13px',
                    fontWeight: isSelected ? 800 : isToday ? 700 : 500,
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    border: isSelected
                      ? '1.5px solid #2563eb'
                      : isToday
                      ? '1.5px solid #10b981'
                      : '1px solid transparent',
                    backgroundColor: isSelected
                      ? '#2563eb'
                      : isToday
                      ? '#ecfdf5'
                      : '#ffffff',
                    color: isSelected ? '#ffffff' : isToday ? '#065f46' : '#1e293b',
                    boxShadow: isSelected
                      ? '0 3px 8px rgba(37, 99, 235, 0.25)'
                      : 'none',
                    position: 'relative',
                  }}
                >
                  {dayNum}
                  {isToday && !isSelected && (
                    <span
                      style={{
                        position: 'absolute',
                        bottom: '3px',
                        width: '4px',
                        height: '4px',
                        borderRadius: '50%',
                        backgroundColor: '#10b981',
                      }}
                    />
                  )}
                </button>
              );
            })}
          </div>

          {/* Selected Date Summary Banner */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              padding: '10px 12px',
              backgroundColor: '#f1f5f9',
              borderRadius: '12px',
              fontSize: '12px',
              color: '#334155',
            }}
          >
            <CalendarIcon size={14} className="text-blue-600 flex-shrink-0" />
            <div style={{ flex: 1, minWidth: 0 }}>
              <span style={{ color: '#64748b', fontSize: '11px', display: 'block' }}>
                Selected Date:
              </span>
              <strong style={{ color: '#0f172a', fontWeight: 700 }}>
                {formatDatePretty(pendingDate)}
              </strong>
            </div>
            {pendingDate === todayStr && (
              <span
                style={{
                  fontSize: '10px',
                  fontWeight: 700,
                  padding: '2px 6px',
                  borderRadius: '9999px',
                  backgroundColor: '#dcfce7',
                  color: '#166534',
                }}
              >
                Today
              </span>
            )}
          </div>
        </div>

        {/* Footer: Cancel & Apply */}
        <div
          className="v2-modal__footer"
          style={{
            padding: '14px 20px',
            backgroundColor: '#fafbfc',
            borderTop: '1px solid #e2e8f0',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            gap: '10px',
          }}
        >
          <button
            type="button"
            onClick={onClose}
            style={{
              padding: '8px 16px',
              borderRadius: '10px',
              border: '1px solid #cbd5e1',
              backgroundColor: '#ffffff',
              color: '#475569',
              fontSize: '13px',
              fontWeight: 600,
              cursor: 'pointer',
              transition: 'background-color 0.15s ease',
            }}
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleApply}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              padding: '8px 18px',
              borderRadius: '10px',
              border: 'none',
              backgroundColor: '#2563eb',
              color: '#ffffff',
              fontSize: '13px',
              fontWeight: 700,
              cursor: 'pointer',
              boxShadow: '0 2px 6px rgba(37, 99, 235, 0.25)',
              transition: 'all 0.15s ease',
            }}
          >
            <Check size={15} strokeWidth={2.5} />
            <span>Apply</span>
          </button>
        </div>
      </div>
    </div>
  );
}
