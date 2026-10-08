export interface BusinessSlot {
  start24: string;
  end24: string;
  startM: number;
  endM: number;
  startLabel: string;
  endLabel: string;
  label: string;
}

export interface TimePoint {
  time24: string;
  label12: string;
  minutes: number;
}

export type V2StatusKey = 'booked' | 'in_service' | 'completed' | 'no_show' | 'cancelled';

export interface StatusMeta {
  key: V2StatusKey;
  label: string;
  colorName: 'Blue' | 'Orange' | 'Green' | 'Red' | 'Grey';
  color: string;
  bg: string;
  border: string;
  badgeBg: string;
  badgeText: string;
}

export const V2_STATUS_MAP: Record<V2StatusKey, StatusMeta> = {
  booked: {
    key: 'booked',
    label: 'Booked',
    colorName: 'Blue',
    color: '#2563eb',
    bg: '#eff6ff',
    border: '#3b82f6',
    badgeBg: '#dbeafe',
    badgeText: '#1e40af',
  },
  in_service: {
    key: 'in_service',
    label: 'In Service',
    colorName: 'Orange',
    color: '#d97706',
    bg: '#fffbeb',
    border: '#f59e0b',
    badgeBg: '#fef3c7',
    badgeText: '#b45309',
  },
  completed: {
    key: 'completed',
    label: 'Completed',
    colorName: 'Green',
    color: '#059669',
    bg: '#ecfdf5',
    border: '#10b981',
    badgeBg: '#d1fae5',
    badgeText: '#065f46',
  },
  no_show: {
    key: 'no_show',
    label: 'No Show',
    colorName: 'Red',
    color: '#dc2626',
    bg: '#fef2f2',
    border: '#ef4444',
    badgeBg: '#fee2e2',
    badgeText: '#991b1b',
  },
  cancelled: {
    key: 'cancelled',
    label: 'Cancelled',
    colorName: 'Grey',
    color: '#64748b',
    bg: '#f8fafc',
    border: '#94a3b8',
    badgeBg: '#f1f5f9',
    badgeText: '#475569',
  },
};

export function getStatusMeta(status?: string): StatusMeta {
  const norm = (status || 'booked').toLowerCase().replace('-', '_');
  if (norm === 'inservice' || norm === 'in_service') return V2_STATUS_MAP.in_service;
  if (norm === 'completed') return V2_STATUS_MAP.completed;
  if (norm === 'noshow' || norm === 'no_show') return V2_STATUS_MAP.no_show;
  if (norm === 'cancelled' || norm === 'canceled') return V2_STATUS_MAP.cancelled;
  return V2_STATUS_MAP.booked;
}

export function timeToMinutes(time24: string): number {
  if (!time24) return 0;
  const trimmed = time24.trim();
  const parts = trimmed.split(':');
  if (parts.length >= 2) {
    const h = parseInt(parts[0] || '0', 10) || 0;
    const m = parseInt(parts[1] || '0', 10) || 0;
    return h * 60 + m;
  }
  return 0;
}

export function minutesToTime24(totalMinutes: number): string {
  const h = Math.floor(totalMinutes / 60) % 24;
  const m = totalMinutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function formatTime12(time24: string): string {
  if (!time24) return '--:--';
  const mins = timeToMinutes(time24);
  const h24 = Math.floor(mins / 60) % 24;
  const m = mins % 60;
  const period = h24 >= 12 ? 'PM' : 'AM';
  let h12 = h24 % 12;
  if (h12 === 0) h12 = 12;
  return `${h12}:${String(m).padStart(2, '0')} ${period}`;
}

export function formatTimeSlotLabel(start24: string, end24: string, format: '12' | '24' = '12'): string {
  if (format === '24') {
    return `${start24} – ${end24}`;
  }
  return `${formatTime12(start24)} – ${formatTime12(end24)}`;
}

export function getTodayDateStr(): string {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function formatDatePretty(dateStr: string): string {
  if (!dateStr) return '';
  const [y, m, d] = dateStr.split('-').map((v) => parseInt(v, 10));
  if (!y || !m || !d) return dateStr;
  const dt = new Date(y, m - 1, d);
  return dt.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

/**
 * Generates all 30-minute intervals between openTime and closeTime (inclusive start, exclusive end)
 * Example: 08:00 to 20:00 -> [08:00-08:30, 08:30-09:00, ..., 19:30-20:00]
 */
export function generateBusinessSlots(
  openTime = '08:00',
  closeTime = '20:00',
  intervalMinutes = 30
): BusinessSlot[] {
  const startM = timeToMinutes(openTime);
  const endM = timeToMinutes(closeTime);
  const slots: BusinessSlot[] = [];

  const effectiveEnd = endM > startM ? endM : 20 * 60;
  let cur = startM;

  while (cur + intervalMinutes <= effectiveEnd) {
    const next = cur + intervalMinutes;
    const start24 = minutesToTime24(cur);
    const end24 = minutesToTime24(next);
    slots.push({
      start24,
      end24,
      startM: cur,
      endM: next,
      startLabel: formatTime12(start24),
      endLabel: formatTime12(end24),
      label: `${formatTime12(start24)} – ${formatTime12(end24)}`,
    });
    cur = next;
  }

  return slots;
}

/**
 * Generates discrete time points for Start Time & End Time selection
 * From openTime to closeTime in 30-minute steps
 * Example: 08:00, 08:30, 09:00, ..., 20:00
 */
export function generateTimePoints(
  openTime = '08:00',
  closeTime = '20:00',
  stepMinutes = 30
): TimePoint[] {
  const startM = timeToMinutes(openTime);
  const endM = timeToMinutes(closeTime);
  const effectiveEnd = endM > startM ? endM : 20 * 60;
  const points: TimePoint[] = [];

  let cur = startM;
  while (cur <= effectiveEnd) {
    const time24 = minutesToTime24(cur);
    points.push({
      time24,
      label12: formatTime12(time24),
      minutes: cur,
    });
    cur += stepMinutes;
  }

  return points;
}

/**
 * Client-side conflict check for immediate responsiveness before/alongside API call
 */
export function checkClientOverlap(
  existingAppts: Array<{
    id?: number;
    start_time: string;
    end_time: string;
    status: string;
  }>,
  newStart24: string,
  newEnd24: string,
  excludeId?: number | null
): { hasConflict: boolean; conflictingAppt?: any } {
  const newStart = timeToMinutes(newStart24);
  const newEnd = timeToMinutes(newEnd24);

  const blocking = existingAppts.filter((a) => {
    if (excludeId && String(a.id) === String(excludeId)) return false;
    const norm = (a.status || '').toLowerCase();
    return norm === 'booked' || norm === 'in_service' || norm === 'completed';
  });

  for (const a of blocking) {
    const aStart = timeToMinutes(a.start_time);
    const aEnd = timeToMinutes(a.end_time);
    if (newStart < aEnd && aStart < newEnd) {
      return { hasConflict: true, conflictingAppt: a };
    }
  }

  return { hasConflict: false };
}
