import { useState, type FormEvent } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { toast } from 'react-toastify';
import {
  LogIn,
  Calendar,
  Shield,
  Zap,
  CheckCircle2,
  Clock4,
  Lock,
  Mail,
  Eye,
  EyeOff,
  ArrowRight,
  Sparkles,
  Globe,
} from 'lucide-react';
import { useAppDispatch } from '../store/hooks';
import { loginSuccess } from '../features/auth/authSlice';
import { authApi } from '../api/authApi';
import '../styles/auth.css';

export default function LoginScreen() {
  const dispatch = useAppDispatch();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [remember, setRemember] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setErrorMsg('');

    if (!email.trim() || !password.trim()) {
      setErrorMsg('Please fill in all fields');
      return;
    }

    try {
      setLoading(true);
      const res = await authApi.login({ email: email.trim(), password });

      const { token, business } = res.data;
      dispatch(loginSuccess({ token, business }));
      toast.success(`Welcome back, ${business.owner_name || 'User'}!`);
      navigate('/dashboard', { replace: true });
    } catch (err: any) {
      const msg =
        err?.response?.data?.message ||
        err?.response?.data?.error ||
        'Login failed. Please try again.';
      setErrorMsg(msg);
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      {/* Background decoration */}
      <div className="auth-bg-circle auth-bg-circle--top" />
      <div className="auth-bg-circle auth-bg-circle--bottom" />

      {/* Header */}
      <header className="auth-header">
        <div className="auth-header__brand">
          <div className="auth-header__logo-box">
            <Calendar size={22} color="#fff" />
          </div>
          <div>
            <div className="auth-header__title">IQ Store</div>
            <div className="auth-header__subtitle">CLINICAL &amp; RETAIL TERMINAL</div>
          </div>
        </div>
        <Link to="/register" className="auth-header__action-btn">
          <Sparkles size={14} />
          Create Account
        </Link>
      </header>

      {/* Content */}
      <div className="auth-content">
        <div className="auth-content__inner">
          <div className="auth-layout-row">
            {/* Left hero */}
            <div className="auth-hero-col">
              <div className="hero-badge">
                <Shield size={12} />
                ENTERPRISE GRADE SECURITY
              </div>
              <h1 className="hero-headline">
                Unified Clinic &amp;<br />
                Retail Management
              </h1>
              <p className="hero-subtitle">
                Streamline your business operations with our integrated terminal
                system. Manage appointments, process sales, and track inventory —
                all in one place.
              </p>
              <div className="hero-features">
                <div className="hero-feature-card">
                  <div
                    className="hero-feature-icon"
                    style={{ background: 'rgba(180, 41, 7, 0.1)' }}
                  >
                    <Calendar size={20} color="var(--primary)" />
                  </div>
                  <div className="hero-feature-title">Appointments</div>
                  <div className="hero-feature-desc">
                    Smart scheduling with automated reminders and waitlist
                    management.
                  </div>
                </div>
                <div className="hero-feature-card">
                  <div
                    className="hero-feature-icon"
                    style={{ background: 'rgba(0, 108, 73, 0.1)' }}
                  >
                    <Zap size={20} color="var(--tertiary)" />
                  </div>
                  <div className="hero-feature-title">Retail POS</div>
                  <div className="hero-feature-desc">
                    Quick checkout, inventory tracking, and seamless payment
                    processing.
                  </div>
                </div>
              </div>
              <div className="hero-trust-badges">
                <span className="hero-trust-badge">
                  <CheckCircle2 size={14} color="var(--tertiary)" />
                  SOC 2 Compliant
                </span>
                <span className="hero-trust-badge">
                  <CheckCircle2 size={14} color="var(--tertiary)" />
                  HIPAA Ready
                </span>
                <span className="hero-trust-badge">
                  <Clock4 size={14} color="var(--tertiary)" />
                  99.9% Uptime
                </span>
              </div>
            </div>

            {/* Login Card */}
            <div className="auth-card-col">
              <form className="auth-card" onSubmit={handleSubmit}>
                <div className="auth-card__header">
                  <div className="auth-card__icon-box">
                    <LogIn size={22} color="#fff" />
                  </div>
                  <button type="button" className="auth-card__demo-btn" tabIndex={-1}>
                    <Sparkles size={12} />
                    Demo
                  </button>
                </div>

                <h2 className="auth-card__title">Welcome Back</h2>
                <p className="auth-card__desc">
                  Sign in to access your business terminal
                </p>

                {errorMsg && (
                  <div className="auth-error-box">
                    <Shield size={14} color="var(--error)" />
                    <span className="auth-error-box__text">{errorMsg}</span>
                  </div>
                )}

                <div className="auth-form">
                  {/* Email */}
                  <div className="field-group">
                    <label className="field-label">
                      <Mail size={14} className="field-label__icon" />
                      Email Address
                    </label>
                    <input
                      id="login-email"
                      type="email"
                      className="auth-input"
                      placeholder="owner@business.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      autoComplete="email"
                    />
                  </div>

                  {/* Password */}
                  <div className="field-group">
                    <div className="field-label-row">
                      <label className="field-label" style={{ marginBottom: 0 }}>
                        <Lock size={14} className="field-label__icon" />
                        Password
                      </label>
                      <button type="button" className="forgot-link" tabIndex={-1}>
                        Forgot?
                      </button>
                    </div>
                    <div className="password-wrapper">
                      <input
                        id="login-password"
                        type={showPassword ? 'text' : 'password'}
                        className="auth-input"
                        placeholder="Enter your password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        autoComplete="current-password"
                      />
                      <button
                        type="button"
                        className="password-toggle"
                        onClick={() => setShowPassword(!showPassword)}
                        tabIndex={-1}
                      >
                        {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                      </button>
                    </div>
                  </div>

                  {/* Remember + Station */}
                  <div className="auth-options-row">
                    <div className="auth-remember">
                      <input
                        id="remember"
                        type="checkbox"
                        checked={remember}
                        onChange={(e) => setRemember(e.target.checked)}
                      />
                      <label htmlFor="remember">Remember me</label>
                    </div>
                    <div className="auth-station">
                      <div className="auth-station__dot" />
                      <span className="auth-station__text">Station #01</span>
                    </div>
                  </div>

                  {/* Submit */}
                  <button
                    id="login-submit"
                    type="submit"
                    className="auth-submit-btn"
                    disabled={loading}
                  >
                    {loading ? (
                      <span className="auth-submit-spinner" />
                    ) : (
                      <>
                        Sign In to Terminal
                        <ArrowRight size={18} />
                      </>
                    )}
                  </button>
                </div>

                <div className="auth-switch">
                  <span>Don&apos;t have an account?</span>
                  <Link to="/register" className="auth-switch__link">
                    Create Business Account
                  </Link>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="auth-footer">
        <span className="auth-footer__item">
          <Lock size={12} />
          256-bit Encryption
        </span>
        <span className="auth-footer__item">
          <Globe size={12} />
          GDPR Compliant
        </span>
        <span className="auth-footer__item">
          <Shield size={12} />
          SOC 2 Type II
        </span>
      </footer>
    </div>
  );
}
