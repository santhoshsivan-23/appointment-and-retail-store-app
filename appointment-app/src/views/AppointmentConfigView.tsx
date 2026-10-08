import { useState, useEffect } from 'react';
import { toast } from 'react-toastify';
import {
  Clock,
  Timer,
  Calendar,
  Sun,
  Moon,
  Save,
  CheckCircle2,
  Circle,
  Sliders,
  Trash2,
} from 'lucide-react';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import { saveAppointmentConfig } from '../features/appointmentConfig/appointmentConfigSlice';
import '../styles/appointment_config.css';

export default function AppointmentConfigView() {
  const dispatch = useAppDispatch();
  const config = useAppSelector((state) => state.appointmentConfig);

  /* ── Local Form State ─────────────────────────────────── */
  const [timeFormat, setTimeFormatState] = useState<'12' | '24'>(config.timeFormat || '12');
  const [slotDuration, setSlotDurationState] = useState<number>(config.slotDuration || 30);
  const [bufferTime, setBufferTimeState] = useState<number>(config.bufferTime || 10);
  const [openTime, setOpenTime] = useState<string>(config.openTime || '08:00');
  const [closeTime, setCloseTime] = useState<string>(config.closeTime || '20:00');
  const [allowWalkInQueue, setAllowWalkInQueue] = useState<boolean>(config.allowWalkInQueue);
  const [requireDoctorNotes, setRequireDoctorNotes] = useState<boolean>(config.requireDoctorNotes);
  const [allowDeleteService, setAllowDeleteService] = useState<boolean>(config.allowDeleteService);

  // Sync if Redux state updates externally
  useEffect(() => {
    setTimeFormatState(config.timeFormat);
    setSlotDurationState(config.slotDuration);
    setBufferTimeState(config.bufferTime);
    setOpenTime(config.openTime);
    setCloseTime(config.closeTime);
    setAllowWalkInQueue(config.allowWalkInQueue);
    setRequireDoctorNotes(config.requireDoctorNotes);
    setAllowDeleteService(config.allowDeleteService);
  }, [config]);

  /* ── Save Action ──────────────────────────────────────── */
  const handleSave = () => {
    const payload = {
      timeFormat,
      slotDuration,
      bufferTime,
      openTime: openTime.trim() || '08:00',
      closeTime: closeTime.trim() || '20:00',
      allowWalkInQueue,
      requireDoctorNotes,
      allowDeleteService,
    };

    dispatch(saveAppointmentConfig(payload));

    const formatDesc = timeFormat === '12' ? '12-Hour AM/PM' : '24-Hour';
    toast.success(
      `Appointment configuration saved successfully! (Format: ${formatDesc})`,
      {
        icon: <CheckCircle2 color="#10B981" size={20} />,
      },
    );
  };

  return (
    <div className="appointment-config-view">
      {/* ── Page Header ────────────────────────────────────── */}
      <div className="ac-header">
        <div className="ac-header-title-row">
          <div className="ac-header-badge">
            <Sliders size={20} />
          </div>
          <div>
            <h2 className="ac-title">Appointment Configuration & Rules</h2>
            <p className="ac-subtitle">
              Configure operational booking intervals, time format (12h/24h), buffer times, and clinic schedule policies.
            </p>
          </div>
        </div>
      </div>

      {/* ── Configuration Card ─────────────────────────────── */}
      <div className="ac-card">
        {/* 1. Time Format & Clock Display */}
        <div className="ac-format-box">
          <div className="ac-format-header">
            <div className="ac-format-icon-wrap">
              <Calendar size={18} />
            </div>
            <div>
              <h3 className="ac-section-title" style={{ margin: 0 }}>
                1. Time Format & Clock Display
              </h3>
              <p className="ac-section-desc" style={{ margin: '2px 0 0', fontSize: '12px' }}>
                Controls whether appointment times use 12-hour (with AM/PM dropdown) or 24-hour notation:
              </p>
            </div>
          </div>

          <div className="ac-format-options-grid">
            {/* 12-Hour Option */}
            <div
              className={`ac-format-card ${timeFormat === '12' ? 'ac-format-card--active' : ''}`}
              onClick={() => setTimeFormatState('12')}
            >
              <div className="ac-format-card__icon-box">
                <Clock size={18} />
              </div>
              <div className="ac-format-card__info">
                <div className="ac-format-card__title">12-Hour Format</div>
                <div className="ac-format-card__sub">AM / PM Dropdown Selector</div>
              </div>
              <div className="ac-format-card__radio">
                {timeFormat === '12' ? <CheckCircle2 size={20} /> : <Circle size={20} />}
              </div>
            </div>

            {/* 24-Hour Option */}
            <div
              className={`ac-format-card ${timeFormat === '24' ? 'ac-format-card--active' : ''}`}
              onClick={() => setTimeFormatState('24')}
            >
              <div className="ac-format-card__icon-box">
                <Timer size={18} />
              </div>
              <div className="ac-format-card__info">
                <div className="ac-format-card__title">24-Hour Format</div>
                <div className="ac-format-card__sub">00:00 - 23:59 Standard Time</div>
              </div>
              <div className="ac-format-card__radio">
                {timeFormat === '24' ? <CheckCircle2 size={20} /> : <Circle size={20} />}
              </div>
            </div>
          </div>
        </div>

        <hr className="ac-divider" />

        {/* 2. Booking Slot Interval */}
        <div>
          <div className="ac-section-header">
            <div className="ac-section-icon-badge">
              <Clock size={16} />
            </div>
            <h3 className="ac-section-title" style={{ margin: 0 }}>
              2. Booking Slot Interval
            </h3>
          </div>
          <p className="ac-section-desc">
            Controls duration grid for clinician slots and salon schedules:
          </p>

          <div className="ac-chips-wrap ac-chips-wrap--intervals">
            {[15, 30, 45, 60].map((mins) => {
              const isSelected = slotDuration === mins;
              return (
                <button
                  key={mins}
                  type="button"
                  className={`ac-chip ${isSelected ? 'ac-chip--active-primary' : ''}`}
                  onClick={() => setSlotDurationState(mins)}
                >
                  {mins} Minutes
                </button>
              );
            })}
          </div>
        </div>

        <hr className="ac-divider" />

        {/* 3. Buffer Time Between Sessions */}
        <div>
          <div className="ac-section-header">
            <div className="ac-section-icon-badge">
              <Timer size={16} />
            </div>
            <h3 className="ac-section-title" style={{ margin: 0 }}>
              3. Buffer Time Between Sessions
            </h3>
          </div>
          <p className="ac-section-desc">
            Automatic sanitation and preparation window added after each appointment:
          </p>

          <div className="ac-chips-wrap ac-chips-wrap--buffers">
            {[0, 5, 10, 15, 20].map((mins) => {
              const isSelected = bufferTime === mins;
              return (
                <button
                  key={mins}
                  type="button"
                  className={`ac-chip ${isSelected ? 'ac-chip--active-secondary' : ''}`}
                  onClick={() => setBufferTimeState(mins)}
                >
                  {mins === 0 ? 'No Buffer' : `${mins} Min Buffer`}
                </button>
              );
            })}
          </div>
        </div>

        <hr className="ac-divider" />

        {/* 4. Operating Business Hours */}
        <div>
          <div className="ac-section-header">
            <div className="ac-section-icon-badge">
              <Sun size={16} />
            </div>
            <h3 className="ac-section-title" style={{ margin: 0 }}>
              4. Operating Business Hours
            </h3>
          </div>
          <p className="ac-section-desc">
            Only appointment bookings within these operating hours will be validated and accepted:
          </p>

          <div className="ac-hours-grid">
            <div className="ac-hour-field">
              <label className="ac-hour-label">Opening Time (24h e.g. 08:00)</label>
              <div className="ac-hour-input-wrap">
                <Sun size={18} className="ac-hour-input-icon" />
                <input
                  type="text"
                  className="ac-hour-input"
                  placeholder="08:00"
                  value={openTime}
                  onChange={(e) => setOpenTime(e.target.value)}
                />
              </div>
            </div>

            <div className="ac-hour-field">
              <label className="ac-hour-label">Closing Time (24h e.g. 20:00)</label>
              <div className="ac-hour-input-wrap">
                <Moon size={18} className="ac-hour-input-icon" />
                <input
                  type="text"
                  className="ac-hour-input"
                  placeholder="20:00"
                  value={closeTime}
                  onChange={(e) => setCloseTime(e.target.value)}
                />
              </div>
            </div>
          </div>
        </div>

        <hr className="ac-divider" />

        {/* 5. Terminal Policies */}
        <div>
          <div className="ac-section-header">
            <div className="ac-section-icon-badge">
              <Sliders size={16} />
            </div>
            <h3 className="ac-section-title" style={{ margin: 0 }}>
              5. Terminal Policies
            </h3>
          </div>
          <p className="ac-section-desc">
            Operational rules enforced across the appointments terminal:
          </p>

          <div className="ac-switch-list">
            <div className="ac-switch-tile">
              <div className="ac-switch-info">
                <div className="ac-switch-title">Allow Instant Walk-in Queue Insertion</div>
                <div className="ac-switch-subtitle">
                  Allows front desk to slot walk-in patients immediately between scheduled appointments.
                </div>
              </div>
              <label className="ac-toggle">
                <input
                  type="checkbox"
                  checked={allowWalkInQueue}
                  onChange={(e) => setAllowWalkInQueue(e.target.checked)}
                />
                <span className="ac-toggle-slider" />
              </label>
            </div>

            <div className="ac-switch-tile">
              <div className="ac-switch-info">
                <div className="ac-switch-title">Enforce Post-Consultation Notes</div>
                <div className="ac-switch-subtitle">
                  Requires clinician to record observation notes before marking appointment completed.
                </div>
              </div>
              <label className="ac-toggle">
                <input
                  type="checkbox"
                  checked={requireDoctorNotes}
                  onChange={(e) => setRequireDoctorNotes(e.target.checked)}
                />
                <span className="ac-toggle-slider" />
              </label>
            </div>
          </div>
        </div>

        <hr className="ac-divider" />

        {/* 6. Delete Service Configuration */}
        <div>
          <div className="ac-section-header">
            <div className="ac-section-icon-badge ac-section-icon-badge--error">
              <Trash2 size={16} />
            </div>
            <h3 className="ac-section-title" style={{ margin: 0 }}>
              6. Delete Service Configuration
            </h3>
          </div>
          <p className="ac-section-desc">
            Controls whether appointments that are currently In Service can be deleted directly:
          </p>

          <div className="ac-switch-list">
            <div className="ac-switch-tile">
              <div className="ac-switch-info">
                <div className="ac-switch-title">Enable Delete Service for In-Service Appointments</div>
                <div className="ac-switch-subtitle">
                  When enabled, a Delete option is displayed with a confirmation dialog for appointments currently In Service.
                </div>
              </div>
              <label className="ac-toggle ac-toggle--error">
                <input
                  type="checkbox"
                  checked={allowDeleteService}
                  onChange={(e) => setAllowDeleteService(e.target.checked)}
                />
                <span className="ac-toggle-slider" />
              </label>
            </div>
          </div>
        </div>

        {/* Save Button */}
        <div className="ac-actions-row">
          <button type="button" className="ac-save-btn" onClick={handleSave}>
            <Save size={18} />
            <span>Save Configuration</span>
          </button>
        </div>
      </div>
    </div>
  );
}
