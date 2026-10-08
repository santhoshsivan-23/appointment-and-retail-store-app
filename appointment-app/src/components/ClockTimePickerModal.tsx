import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Clock, X, Check } from 'lucide-react';
import '../styles/clock_time_picker.css';

interface ClockTimePickerModalProps {
  isOpen: boolean;
  initialTime24: string; // e.g. '08:30'
  label?: string; // e.g. 'Start Time'
  onClose: () => void;
  onSelectTime: (time24: string) => void;
}

const DIAL_RADIUS = 84; // px from center to number bubble
const DIAL_CENTER = 120; // px center of the 240px dial

// Helper: Calculate shortest rotation angle difference to prevent spinning around
function getShortestAngle(currentAngle: number, targetAngle: number): number {
  const normCurrent = ((currentAngle % 360) + 360) % 360;
  const normTarget = ((targetAngle % 360) + 360) % 360;
  let diff = normTarget - normCurrent;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return currentAngle + diff;
}

export default function ClockTimePickerModal({
  isOpen,
  initialTime24,
  label = 'Select Time',
  onClose,
  onSelectTime,
}: ClockTimePickerModalProps) {
  const [mode, setMode] = useState<'hours' | 'minutes'>('hours');
  const [hour12, setHour12] = useState<number>(8);
  const [minute, setMinute] = useState<number>(0);
  const [period, setPeriod] = useState<'AM' | 'PM'>('AM');

  // Continuous angle for smooth hand animations
  const [handAngle, setHandAngle] = useState<number>(240);
  const [isDragging, setIsDragging] = useState<boolean>(false);

  const dialRef = useRef<HTMLDivElement | null>(null);
  const isDraggingRef = useRef<boolean>(false);
  const pointerStartRef = useRef<{ x: number; y: number } | null>(null);

  // Parse initial 24-hour time whenever modal opens
  useEffect(() => {
    if (!isOpen) return;
    const parts = (initialTime24 || '08:00').trim().split(':');
    const h24 = parseInt(parts[0], 10) || 0;
    const m = parseInt(parts[1], 10) || 0;

    const isPM = h24 >= 12;
    const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
    const safeM = Math.max(0, Math.min(59, m));

    setHour12(h12);
    setMinute(safeM);
    setPeriod(isPM ? 'PM' : 'AM');
    setMode('hours'); // Start on hours mode
    setHandAngle(h12 * 30);
    setIsDragging(false);
  }, [isOpen, initialTime24]);

  // Convert current 12-hour + AM/PM state to 24-hour format string ('HH:MM')
  const getTime24 = useCallback(() => {
    let h24 = hour12;
    if (period === 'AM') {
      if (hour12 === 12) h24 = 0;
    } else {
      if (hour12 < 12) h24 = hour12 + 12;
    }
    const hStr = String(h24).padStart(2, '0');
    const mStr = String(minute).padStart(2, '0');
    return `${hStr}:${mStr}`;
  }, [hour12, minute, period]);

  // Smooth mode switcher
  const switchMode = useCallback(
    (newMode: 'hours' | 'minutes') => {
      setMode(newMode);
      setIsDragging(false);
      const targetDeg = newMode === 'hours' ? hour12 * 30 : minute * 6;
      setHandAngle((prev) => getShortestAngle(prev, targetDeg));
    },
    [hour12, minute]
  );

  // Direct number click handlers (smooth animation without dragging)
  const handleSelectHour = useCallback((h: number) => {
    setIsDragging(false);
    isDraggingRef.current = false;
    setHour12(h);
    const targetDeg = h * 30;
    setHandAngle((prev) => getShortestAngle(prev, targetDeg));

    // Smoothly advance to minute mode after animation completes
    setTimeout(() => {
      setMode('minutes');
      setHandAngle((prev) => getShortestAngle(prev, minute * 6));
    }, 320);
  }, [minute]);

  const handleSelectMinute = useCallback((m: number) => {
    setIsDragging(false);
    isDraggingRef.current = false;
    setMinute(m);
    const targetDeg = m * 6;
    setHandAngle((prev) => getShortestAngle(prev, targetDeg));
  }, []);

  // Handle pointer angle calculation relative to clock center
  const handlePointerAngle = useCallback(
    (clientX: number, clientY: number, isFinal: boolean) => {
      if (!dialRef.current) return;
      const rect = dialRef.current.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;

      const deltaX = clientX - centerX;
      const deltaY = clientY - centerY;

      // Calculate angle in degrees from 12 o'clock (top) clockwise
      let angle = (Math.atan2(deltaY, deltaX) * 180) / Math.PI + 90;
      if (angle < 0) angle += 360;

      if (mode === 'hours') {
        let selectedH = Math.round(angle / 30) % 12;
        if (selectedH === 0) selectedH = 12;
        setHour12(selectedH);

        const snapAngle = selectedH * 30;
        if (isFinal) {
          setIsDragging(false);
          setHandAngle((prev) => getShortestAngle(prev, snapAngle));
          setTimeout(() => {
            setMode('minutes');
            setHandAngle((prev) => getShortestAngle(prev, minute * 6));
          }, 320);
        } else {
          setHandAngle(angle);
        }
      } else {
        // Minutes mode
        const selectedM = Math.round(angle / 6) % 60;
        setMinute(selectedM);

        const snapAngle = selectedM * 6;
        if (isFinal) {
          setIsDragging(false);
          setHandAngle((prev) => getShortestAngle(prev, snapAngle));
        } else {
          setHandAngle(angle);
        }
      }
    },
    [mode, minute]
  );

  // Pointer event listeners on dial
  const handlePointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    pointerStartRef.current = { x: e.clientX, y: e.clientY };
    isDraggingRef.current = false;
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!pointerStartRef.current) return;
    const dist = Math.hypot(
      e.clientX - pointerStartRef.current.x,
      e.clientY - pointerStartRef.current.y
    );
    if (dist > 6 && !isDraggingRef.current) {
      isDraggingRef.current = true;
      setIsDragging(true);
    }
    if (isDraggingRef.current) {
      handlePointerAngle(e.clientX, e.clientY, false);
    }
  };

  const handlePointerUp = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!pointerStartRef.current) return;
    pointerStartRef.current = null;
    isDraggingRef.current = false;
    setIsDragging(false);

    // If tapped/clicked or released after dragging, smoothly snap
    handlePointerAngle(e.clientX, e.clientY, true);
  };

  const handleConfirm = () => {
    onSelectTime(getTime24());
    onClose();
  };

  if (!isOpen) return null;

  // Precomputed numbers
  const hoursList = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
  const minutesList = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  return (
    <div className="clock-picker-overlay" onClick={onClose}>
      <div className="clock-picker-modal" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="clock-picker-header">
          <div className="clock-picker-title-row">
            <Clock size={16} color="#1e40af" />
            <h4 className="clock-picker-title">{label}</h4>
          </div>
          <button
            type="button"
            className="clock-picker-close-btn"
            onClick={onClose}
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        {/* Digital Display & AM/PM Switcher */}
        <div className="clock-picker-display-bar">
          <div className="clock-picker-digits-group">
            <button
              type="button"
              className={`clock-picker-digit-btn ${
                mode === 'hours' ? 'clock-picker-digit-btn--active' : ''
              }`}
              onClick={() => switchMode('hours')}
              title="Select Hour"
            >
              {String(hour12).padStart(2, '0')}
            </button>

            <span className="clock-picker-colon">:</span>

            <button
              type="button"
              className={`clock-picker-digit-btn ${
                mode === 'minutes' ? 'clock-picker-digit-btn--active' : ''
              }`}
              onClick={() => switchMode('minutes')}
              title="Select Minute"
            >
              {String(minute).padStart(2, '0')}
            </button>
          </div>

          <div className="clock-picker-ampm-group">
            <button
              type="button"
              className={`clock-picker-ampm-btn ${
                period === 'AM' ? 'clock-picker-ampm-btn--active' : ''
              }`}
              onClick={() => setPeriod('AM')}
            >
              AM
            </button>
            <button
              type="button"
              className={`clock-picker-ampm-btn ${
                period === 'PM' ? 'clock-picker-ampm-btn--active' : ''
              }`}
              onClick={() => setPeriod('PM')}
            >
              PM
            </button>
          </div>
        </div>

        {/* Mode Instruction Hint */}
        <div className="clock-picker-mode-hint">
          {mode === 'hours' ? 'Select Hour (1 – 12)' : 'Select Minute (00 – 59)'}
        </div>

        {/* Dial Face */}
        <div className="clock-picker-face-wrap">
          <div
            ref={dialRef}
            className="clock-picker-dial"
            onPointerDown={handlePointerDown}
            onPointerMove={handlePointerMove}
            onPointerUp={handlePointerUp}
          >
            {/* Center Pivot Point */}
            <div className="clock-picker-pivot" />

            {/* Rotating Hand Pointer with Selection Bubble */}
            <div
              className={`clock-picker-hand ${isDragging ? 'clock-picker-hand--dragging' : ''}`}
              style={{
                transform: `rotate(${handAngle}deg)`,
              }}
            >
              <div className="clock-picker-hand-bubble">
                {mode === 'minutes' && minute % 5 !== 0 && (
                  <span
                    className="clock-picker-bubble-text"
                    style={{
                      transform: `rotate(-${handAngle}deg)`,
                    }}
                  >
                    {String(minute).padStart(2, '0')}
                  </span>
                )}
              </div>
            </div>

            {/* Numbers on the Clock Face */}
            {mode === 'hours'
              ? hoursList.map((h) => {
                  const angleRad = ((h * 30 - 90) * Math.PI) / 180;
                  const x = DIAL_CENTER + DIAL_RADIUS * Math.cos(angleRad);
                  const y = DIAL_CENTER + DIAL_RADIUS * Math.sin(angleRad);
                  const isActive = hour12 === h;

                  return (
                    <button
                      key={h}
                      type="button"
                      className={`clock-picker-number ${
                        isActive ? 'clock-picker-number--active' : ''
                      }`}
                      style={{ left: `${x}px`, top: `${y}px` }}
                      onClick={(e) => {
                        e.stopPropagation();
                        handleSelectHour(h);
                      }}
                    >
                      {h}
                    </button>
                  );
                })
              : minutesList.map((m) => {
                  const angleRad = ((m * 6 - 90) * Math.PI) / 180;
                  const x = DIAL_CENTER + DIAL_RADIUS * Math.cos(angleRad);
                  const y = DIAL_CENTER + DIAL_RADIUS * Math.sin(angleRad);
                  const isActive = minute === m;

                  return (
                    <button
                      key={m}
                      type="button"
                      className={`clock-picker-number ${
                        isActive ? 'clock-picker-number--active' : ''
                      }`}
                      style={{ left: `${x}px`, top: `${y}px` }}
                      onClick={(e) => {
                        e.stopPropagation();
                        handleSelectMinute(m);
                      }}
                    >
                      {String(m).padStart(2, '0')}
                    </button>
                  );
                })}
          </div>
        </div>

        {/* Footer Actions */}
        <div className="clock-picker-footer">
          <button
            type="button"
            className="clock-picker-btn clock-picker-btn--secondary"
            onClick={onClose}
          >
            Cancel
          </button>
          <button
            type="button"
            className="clock-picker-btn clock-picker-btn--primary"
            onClick={handleConfirm}
          >
            <Check size={14} style={{ display: 'inline', marginRight: 4 }} />
            Set Time
          </button>
        </div>
      </div>
    </div>
  );
}
