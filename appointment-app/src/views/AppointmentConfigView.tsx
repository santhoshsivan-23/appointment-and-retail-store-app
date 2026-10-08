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
  RefreshCw,
} from 'lucide-react';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import {
  saveAppointmentConfig,
  applySyncedSettings,
} from '../features/appointmentConfig/appointmentConfigSlice';
import { settingsApi } from '../api/settingsApi';
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
  const [appointmentV2Clock, setAppointmentV2ClockState] = useState<boolean>(config.appointmentV2Clock ?? true);
  const [isSaving, setIsSaving] = useState<boolean>(false);
  const [isUpdating, setIsUpdating] = useState<boolean>(false);

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
    setAppointmentV2ClockState(config.appointmentV2Clock ?? true);
  }, [config]);

  /* ── Update Settings Action (Fetch from API & Save in Local Storage) ── */
  const handleUpdateSettings = async () => {
    setIsUpdating(true);
    try {
      const res = await settingsApi.getSettings();
      if (res.data?.data) {
        const data = res.data.data;
        // 1. Dispatch applySyncedSettings which updates Redux and persists to Local Storage
        dispatch(applySyncedSettings(data));

        // 2. Refresh local form state
        if (data.time_format) setTimeFormatState(data.time_format);
        const slot = data.booking_slot_interval ?? data.slot_duration ?? 30;
        setSlotDurationState(slot);
        const buffer = data.buffer_time_between_sessions ?? data.buffer_time ?? 10;
        setBufferTimeState(buffer);
        const opOpen = data.open_time || data.operating_business_hours?.open_time || '08:00';
        setOpenTime(opOpen);
        const opClose = data.close_time || data.operating_business_hours?.close_time || '20:00';
        setCloseTime(opClose);
        if (data.allow_walk_in_queue !== undefined) setAllowWalkInQueue(Boolean(data.allow_walk_in_queue));
        if (data.require_doctor_notes !== undefined) setRequireDoctorNotes(Boolean(data.require_doctor_notes));
        if (data.allow_delete_service !== undefined) setAllowDeleteService(Boolean(data.allow_delete_service));
        if (data.appointment_v2_clock !== undefined) setAppointmentV2ClockState(Boolean(data.appointment_v2_clock));

        toast.success('Settings updated from database and saved to Local Storage!', {
          icon: <CheckCircle2 color="#10B981" size={20} />,
        });
      } else {
        toast.warn('No settings returned from server.');
      }
    } catch (err: any) {
      console.error('Failed to update settings from database:', err);
      const msg =
        err?.response?.data?.message ||
        err?.message ||
        'Failed to fetch latest settings from server.';
      toast.error(msg);
    } finally {
      setIsUpdating(false);
    }
  };

  /* ── Save Action ──────────────────────────────────────── */
  const handleSave = async () => {
    const clockDisplay = timeFormat === '24' ? '24h' : '12h';
    const cleanOpen = openTime.trim() || '08:00';
    const cleanClose = closeTime.trim() || '20:00';

    const payload = {
      timeFormat,
      clockDisplay,
      slotDuration,
      bufferTime,
      openTime: cleanOpen,
      closeTime: cleanClose,
      allowWalkInQueue,
      requireDoctorNotes,
      allowDeleteService,
      appointmentV2Clock,
    };

    // 1. Update settings locally in Redux & Local Storage
    dispatch(saveAppointmentConfig(payload));

    // 2. Call the Update Settings API to save changes to the database
    setIsSaving(true);
    try {
      await settingsApi.updateSettings({
        time_format: timeFormat,
        clock_display: clockDisplay,
        booking_slot_interval: slotDuration,
        buffer_time_between_sessions: bufferTime,
        open_time: cleanOpen,
        close_time: cleanClose,
        allow_walk_in_queue: allowWalkInQueue,
        require_doctor_notes: requireDoctorNotes,
        allow_delete_service: allowDeleteService,
        appointment_v2_clock: appointmentV2Clock,
      });

      const formatDesc = timeFormat === '12' ? '12-Hour AM/PM' : '24-Hour';
      toast.success(
        `Appointment configuration saved and synced to database! (Format: ${formatDesc})`,
        {
          icon: <CheckCircle2 color="#10B981" size={20} />,
        },
      );
    } catch (err: any) {
      console.error('Error saving settings to database:', err);
      toast.warn('Saved locally to Local Storage, but could not sync to database.');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="appointment-config-view">
      {/* ── Page Header ────────────────────────────────────── */}
      <div className="ac-header">
        <div className="ac-header-title-row">
          <div className="ac-header-left">
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

          {/* Update Settings Button */}
          <button
            type="button"
            className="ac-update-btn"
            onClick={handleUpdateSettings}
            disabled={isUpdating || isSaving}
            title="Fetch latest settings from database and save to Local Storage"
          >
            <RefreshCw size={16} className={isUpdating ? 'ac-spin' : ''} />
            <span>{isUpdating ? 'Updating Settings...' : 'Update Settings'}</span>
          </button>
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

        <hr className="ac-divider" />

        {/* 7. Add Appointment V2 Popup Configuration */}
        <div>
          <div className="ac-section-header">
            <div className="ac-section-icon-badge ac-section-icon-badge--primary">
              <Clock size={16} />
            </div>
            <h3 className="ac-section-title" style={{ margin: 0 }}>
              7. Add Appointment V2 Popup Configuration
            </h3>
          </div>
          <p className="ac-section-desc">
            Controls the time selector presentation inside the Add Appointment (V2) popup:
          </p>

          <div className="ac-switch-list">
            <div className="ac-switch-tile">
              <div className="ac-switch-info">
                <div className="ac-switch-title">Time Selection Mode</div>
                <div className="ac-switch-subtitle">
                  {appointmentV2Clock
                    ? 'Toggle ON: Use the currently implemented scrolling time selector in the Add Appointment (V2) popup.'
                    : 'Toggle OFF: Use the clock-based time selector in the Add Appointment (V2) popup.'}
                </div>
              </div>
              <label className="ac-toggle">
                <input
                  type="checkbox"
                  checked={appointmentV2Clock}
                  onChange={(e) => setAppointmentV2ClockState(e.target.checked)}
                />
                <span className="ac-toggle-slider" />
              </label>
            </div>
          </div>
        </div>

        {/* Save & Update Buttons */}
        <div className="ac-actions-row">
          <button
            type="button"
            className="ac-update-btn ac-update-btn--secondary"
            onClick={handleUpdateSettings}
            disabled={isUpdating || isSaving}
            title="Fetch latest settings from database and save to Local Storage"
          >
            <RefreshCw size={16} className={isUpdating ? 'ac-spin' : ''} />
            <span>{isUpdating ? 'Updating Settings...' : 'Update Settings'}</span>
          </button>

          <button
            type="button"
            className="ac-save-btn"
            onClick={handleSave}
            disabled={isSaving || isUpdating}
          >
            <Save size={18} />
            <span>{isSaving ? 'Saving & Syncing...' : 'Save Configuration'}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
