import React, { useRef, useState, useEffect, useCallback, useMemo } from 'react';
import { ChevronUp, ChevronDown } from 'lucide-react';
import '../styles/wheel_time_picker.css';

interface WheelColumnProps {
  items: string[];
  selectedIndex: number;
  onSelect: (index: number) => void;
  loop?: boolean;
  itemHeight?: number;
  variant?: 'blue' | 'black';
}

const ITEM_HEIGHT = 34; // px (compact & neat card size)
const CENTER_OFFSET_PX = 2 * ITEM_HEIGHT; // 68px

function WheelColumn({
  items,
  selectedIndex,
  onSelect,
  loop = true,
  itemHeight = ITEM_HEIGHT,
  variant = 'black',
}: WheelColumnProps) {
  const N = items.length;

  // We render 3 sets if loop=true: Set 0, Set 1 (main), Set 2
  const renderedItems = useMemo(() => {
    if (!loop) return items;
    return [...items, ...items, ...items];
  }, [items, loop]);

  // Virtual index tracks the index in renderedItems
  const [virtualIndex, setVirtualIndex] = useState<number>(() => {
    return loop ? N + selectedIndex : selectedIndex;
  });

  const [isAnimating, setIsAnimating] = useState<boolean>(true);
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [dragOffset, setDragOffset] = useState<number>(0);

  const startYRef = useRef<number>(0);
  const startVirtualRef = useRef<number>(0);
  const wheelAccRef = useRef<number>(0);
  const lastWheelStepTimeRef = useRef<number>(0);
  const resetTimeoutRef = useRef<any>(null);

  // Sync virtual index if selectedIndex changes externally
  useEffect(() => {
    if (isDragging) return;
    const target = loop ? N + selectedIndex : selectedIndex;
    const currentReal = loop ? ((virtualIndex % N) + N) % N : virtualIndex;
    if (currentReal !== selectedIndex) {
      setIsAnimating(true);
      setVirtualIndex(target);
    }
  }, [selectedIndex, N, loop, isDragging, virtualIndex]);

  // Step helper: moves by delta steps cleanly
  const stepBy = useCallback(
    (steps: number) => {
      clearTimeout(resetTimeoutRef.current);
      setIsAnimating(true);

      if (loop) {
        const nextVirtual = virtualIndex + steps;
        const realIdx = ((nextVirtual % N) + N) % N;
        setVirtualIndex(nextVirtual);
        onSelect(realIdx);

        // After the 200ms transition, silently reset virtualIndex into the middle set
        resetTimeoutRef.current = setTimeout(() => {
          setIsAnimating(false);
          setVirtualIndex(N + realIdx);
        }, 220);
      } else {
        const nextClamped = Math.max(0, Math.min(N - 1, virtualIndex + steps));
        if (nextClamped !== virtualIndex) {
          setVirtualIndex(nextClamped);
          onSelect(nextClamped);
        }
      }
    },
    [virtualIndex, N, loop, onSelect]
  );

  const containerRef = useRef<HTMLDivElement | null>(null);

  // 1. Native Non-Passive Wheel Listener: strictly prevents parent popup/body from scrolling
  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const handleNativeWheel = (e: WheelEvent) => {
      e.preventDefault();
      e.stopPropagation();

      const now = Date.now();
      wheelAccRef.current += e.deltaY;

      // Threshold for 1 step: 25px
      const THRESHOLD = 25;
      const MIN_INTERVAL_MS = 65; // At least 65ms between steps for neat smooth stepping

      if (
        Math.abs(wheelAccRef.current) >= THRESHOLD &&
        now - lastWheelStepTimeRef.current >= MIN_INTERVAL_MS
      ) {
        const direction = wheelAccRef.current > 0 ? 1 : -1;
        wheelAccRef.current = 0;
        lastWheelStepTimeRef.current = now;
        stepBy(direction);
      }

      clearTimeout(resetTimeoutRef.current);
      resetTimeoutRef.current = setTimeout(() => {
        wheelAccRef.current = 0;
      }, 150);
    };

    el.addEventListener('wheel', handleNativeWheel, { passive: false });
    return () => {
      el.removeEventListener('wheel', handleNativeWheel);
    };
  }, [stepBy]);

  // 2. Touch / Mouse Pointer Dragging
  const handlePointerDown = (e: React.PointerEvent) => {
    setIsDragging(true);
    setIsAnimating(false);
    startYRef.current = e.clientY;
    startVirtualRef.current = virtualIndex;
    setDragOffset(0);
    try {
      (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    } catch {}
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging) return;
    const dy = e.clientY - startYRef.current;
    setDragOffset(dy);
  };

  const handlePointerUp = (e: React.PointerEvent) => {
    if (!isDragging) return;
    setIsDragging(false);
    try {
      (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
    } catch {}

    const dy = e.clientY - startYRef.current;
    const stepsMoved = Math.round(-dy / itemHeight);
    setDragOffset(0);

    if (stepsMoved !== 0) {
      stepBy(stepsMoved);
    } else {
      setIsAnimating(true);
    }
  };

  // Calculate current translation Y
  const translateY = CENTER_OFFSET_PX - virtualIndex * itemHeight + dragOffset;

  return (
    <div
      ref={containerRef}
      className={`drum-wheel-column-container drum-wheel-column-container--${variant}`}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
    >
      {/* Subtle up arrow on hover */}
      <button
        type="button"
        className={`drum-wheel-arrow drum-wheel-arrow--up drum-wheel-arrow--${variant}`}
        onClick={(e) => {
          e.stopPropagation();
          stepBy(-1);
        }}
        title="Previous"
      >
        <ChevronUp size={13} />
      </button>

      {/* Cylinder list of items */}
      <div
        className="drum-wheel-items-track"
        style={{
          transform: `translate3d(0, ${translateY}px, 0)`,
          transition: isAnimating && !isDragging
            ? 'transform 0.22s cubic-bezier(0.16, 1, 0.3, 1)'
            : 'none',
        }}
      >
        {renderedItems.map((item, idx) => {
          const diff = idx - (virtualIndex - dragOffset / itemHeight);
          const absDiff = Math.abs(diff);

          let itemClass = `drum-wheel-item drum-wheel-item--${variant}`;
          if (absDiff < 0.5) itemClass += ' drum-wheel-item--active';
          else if (absDiff < 1.5) itemClass += ' drum-wheel-item--near';
          else if (absDiff < 2.5) itemClass += ' drum-wheel-item--far';
          else itemClass += ' drum-wheel-item--hidden';

          return (
            <div
              key={idx}
              className={itemClass}
              style={{
                height: itemHeight,
                transform: `scale(${Math.max(0.75, 1 - absDiff * 0.08)})`,
              }}
              onClick={(e) => {
                e.stopPropagation();
                if (isDragging) return;
                const offsetFromCenter = idx - virtualIndex;
                if (Math.abs(offsetFromCenter) > 0 && Math.abs(offsetFromCenter) <= 2) {
                  stepBy(offsetFromCenter);
                }
              }}
            >
              {item}
            </div>
          );
        })}
      </div>

      {/* Subtle down arrow on hover */}
      <button
        type="button"
        className={`drum-wheel-arrow drum-wheel-arrow--down drum-wheel-arrow--${variant}`}
        onClick={(e) => {
          e.stopPropagation();
          stepBy(1);
        }}
        title="Next"
      >
        <ChevronDown size={13} />
      </button>
    </div>
  );
}

/* ── Main WheelTimePicker Component ──────────────────────────────────────── */
interface WheelTimePickerProps {
  value: string; // 'HH:MM' 24-hour format (e.g. '12:19', '08:30')
  onChange: (time24: string) => void;
  label?: string;
  timeFormat?: '12' | '24';
}

const HOURS_12 = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
const HOURS_24 = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, '0'));
const MINUTES_ALL = Array.from({ length: 60 }, (_, i) => String(i).padStart(2, '0'));
const PERIODS = ['AM', 'PM'];

export default function WheelTimePicker({
  value,
  onChange,
  label,
  timeFormat = '12',
}: WheelTimePickerProps) {
  // Parse incoming 24-hour string (e.g. '12:19')
  const { hour24, minute } = useMemo(() => {
    const parts = (value || '08:00').trim().split(':');
    const h = parseInt(parts[0], 10) || 0;
    const m = parseInt(parts[1], 10) || 0;
    return {
      hour24: Math.max(0, Math.min(23, h)),
      minute: Math.max(0, Math.min(59, m)),
    };
  }, [value]);

  // Derived 12-hour values
  const isPM = hour24 >= 12;
  const hour12Num = hour24 % 12 === 0 ? 12 : hour24 % 12;
  const hour12Str = String(hour12Num).padStart(2, '0');
  const minuteStr = String(minute).padStart(2, '0');
  const periodStr = isPM ? 'PM' : 'AM';

  // Find indexes
  const hourIndex = useMemo(() => {
    if (timeFormat === '24') {
      return hour24;
    }
    const idx = HOURS_12.indexOf(hour12Str);
    return idx >= 0 ? idx : 0;
  }, [timeFormat, hour24, hour12Str]);

  const minuteIndex = useMemo(() => {
    return Math.max(0, Math.min(59, minute));
  }, [minute]);

  const periodIndex = useMemo(() => {
    return isPM ? 1 : 0;
  }, [isPM]);

  // Handlers
  const handleHourChange = useCallback(
    (newHourIdx: number) => {
      if (timeFormat === '24') {
        const h24 = String(newHourIdx).padStart(2, '0');
        onChange(`${h24}:${minuteStr}`);
      } else {
        const h12 = parseInt(HOURS_12[newHourIdx], 10);
        let newH24 = h12;
        if (periodStr === 'AM') {
          if (h12 === 12) newH24 = 0;
        } else {
          if (h12 < 12) newH24 = h12 + 12;
        }
        const finalH24 = String(newH24).padStart(2, '0');
        onChange(`${finalH24}:${minuteStr}`);
      }
    },
    [timeFormat, periodStr, minuteStr, onChange]
  );

  const handleMinuteChange = useCallback(
    (newMinIdx: number) => {
      const newMStr = MINUTES_ALL[newMinIdx];
      const h24Str = String(hour24).padStart(2, '0');
      onChange(`${h24Str}:${newMStr}`);
    },
    [hour24, onChange]
  );

  const handlePeriodChange = useCallback(
    (newPeriodIdx: number) => {
      const newPeriod = PERIODS[newPeriodIdx];
      let newH24 = hour12Num;
      if (newPeriod === 'AM') {
        if (hour12Num === 12) newH24 = 0;
      } else {
        if (hour12Num < 12) newH24 = hour12Num + 12;
      }
      const finalH24 = String(newH24).padStart(2, '0');
      onChange(`${finalH24}:${minuteStr}`);
    },
    [hour12Num, minuteStr, onChange]
  );

  const formattedDisplay = useMemo(() => {
    if (timeFormat === '24') {
      return `${String(hour24).padStart(2, '0')}:${minuteStr}`;
    }
    return `${hour12Str}:${minuteStr} ${periodStr}`;
  }, [timeFormat, hour24, hour12Str, minuteStr, periodStr]);

  const bodyRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const el = bodyRef.current;
    if (!el) return;
    const preventModalScroll = (e: WheelEvent) => {
      e.preventDefault();
      e.stopPropagation();
    };
    el.addEventListener('wheel', preventModalScroll, { passive: false });
    return () => {
      el.removeEventListener('wheel', preventModalScroll);
    };
  }, []);

  return (
    <div className="drum-wheel-picker-wrapper">
      {label && (
        <div className="drum-wheel-header">
          <span className="drum-wheel-label">{label}</span>
          <span className="drum-wheel-value-badge">{formattedDisplay}</span>
        </div>
      )}

      {/* Main Drum Container: Clean White Background, Reduced Card Size, Text Colored */}
      <div ref={bodyRef} className="drum-wheel-body">
        {/* Center active highlight line / bar */}
        <div className="drum-wheel-center-highlight" />

        {/* Top & Bottom cylinder gradient fade overlays (Smooth White Fade) */}
        <div className="drum-wheel-fade-overlay drum-wheel-fade-overlay--top" />
        <div className="drum-wheel-fade-overlay drum-wheel-fade-overlay--bottom" />

        {/* Columns Grid */}
        <div className="drum-wheel-columns-grid">
          {/* 1. Hours Column (Blue Text) */}
          <div className="drum-wheel-col-wrap drum-wheel-col-wrap--hours">
            <span className="drum-wheel-col-hint drum-wheel-col-hint--blue">HR</span>
            <WheelColumn
              items={timeFormat === '24' ? HOURS_24 : HOURS_12}
              selectedIndex={hourIndex}
              onSelect={handleHourChange}
              loop={true}
              variant="blue"
            />
          </div>

          {/* Colon Separator */}
          <div className="drum-wheel-colon">:</div>

          {/* 2. Minutes Column (Black Text) */}
          <div className="drum-wheel-col-wrap drum-wheel-col-wrap--minutes">
            <span className="drum-wheel-col-hint drum-wheel-col-hint--black">MIN</span>
            <WheelColumn
              items={MINUTES_ALL}
              selectedIndex={minuteIndex}
              onSelect={handleMinuteChange}
              loop={true}
              variant="black"
            />
          </div>

          {/* 3. AM / PM Column (Black Text) */}
          {timeFormat === '12' && (
            <div className="drum-wheel-col-wrap drum-wheel-col-wrap--ampm">
              <span className="drum-wheel-col-hint drum-wheel-col-hint--black">AM/PM</span>
              <WheelColumn
                items={PERIODS}
                selectedIndex={periodIndex}
                onSelect={handlePeriodChange}
                loop={false}
                variant="black"
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
