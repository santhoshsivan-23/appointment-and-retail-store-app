import { useState, useEffect } from 'react';
import { Clock, User, LogOut } from 'lucide-react';
import { useAppSelector } from '../store/hooks';

interface HeaderProps {
  onLogoutClick: () => void;
}

export default function Header({ onLogoutClick }: HeaderProps) {
  const business = useAppSelector((s) => s.auth.business);
  const timeFormat = useAppSelector((s) => s.auth.timeFormat);
  const [currentTime, setCurrentTime] = useState<Date>(new Date());

  // Live ticking clock with 1-second interval
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Format time matching Flutter _formatHeaderTime
  const formatHeaderTime = (date: Date) => {
    const s = String(date.getSeconds()).padStart(2, '0');
    if (timeFormat === '24') {
      const h = String(date.getHours()).padStart(2, '0');
      const m = String(date.getMinutes()).padStart(2, '0');
      return `${h}:${m}:${s}`;
    } else {
      const hours = date.getHours();
      const hour12 = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
      const h = String(hour12).padStart(2, '0');
      const m = String(date.getMinutes()).padStart(2, '0');
      const ampm = hours >= 12 ? 'PM' : 'AM';
      return `${h}:${m}:${s} ${ampm}`;
    }
  };

  // Format date matching Flutter _formatHeaderDate
  const formatHeaderDate = (date: Date) => {
    const weekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekday = weekdays[date.getDay()];
    const month = months[date.getMonth()];
    const day = String(date.getDate()).padStart(2, '0');
    return `${weekday}, ${day} ${month}`;
  };

  const displayName =
    business?.business_name?.trim() ||
    business?.owner_name?.trim() ||
    'IQ Store';

  return (
    <header className="terminal-header">
      {/* Left Corner: IQ App Logo + IQ Store Title */}
      <div className="terminal-header__left">
        <div className="terminal-header__logo" aria-label="IQ Store Logo">
          IQ
        </div>
        <div className="terminal-header__title-group">
          <span className="terminal-header__title">IQ Store</span>
          <span className="terminal-header__subtitle">
            GROOMING &amp; CLINICAL SUITE
          </span>
        </div>
      </div>

      {/* Right Corner: Station Status + Time & Date + Gray Carded User Info + Sign Out */}
      <div className="terminal-header__right">
        {/* Station Indicator */}
        <div className="terminal-station-badge" title="Station 01 Live Connected">
          <span className="terminal-station-badge__dot" />
          <span>Station #01</span>
        </div>

        {/* System Time & Date */}
        <div className="terminal-clock-box">
          <span className="terminal-clock-box__icon">
            <Clock size={16} />
          </span>
          <span className="terminal-clock-box__time">
            {formatHeaderTime(currentTime)}
          </span>
          <span className="terminal-clock-box__divider" />
          <span className="terminal-clock-box__date">
            {formatHeaderDate(currentTime)}
          </span>
        </div>

        {/* User Information Card */}
        <div className="terminal-user-card" title={`Owner: ${business?.owner_name || 'N/A'}`}>
          <div className="terminal-user-card__avatar">
            <User size={15} />
          </div>
          <span className="terminal-user-card__name">{displayName}</span>
        </div>

        {/* Sign Out Terminal */}
        <button
          type="button"
          className="terminal-header__logout-btn"
          title="Sign Out Terminal"
          onClick={onLogoutClick}
          aria-label="Sign Out"
        >
          <LogOut size={19} />
        </button>
      </div>
    </header>
  );
}
