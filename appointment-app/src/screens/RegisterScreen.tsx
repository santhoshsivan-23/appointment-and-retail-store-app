import { useState, type FormEvent } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { toast } from 'react-toastify';
import {
  UserPlus,
  Calendar,
  Shield,
  Zap,
  CheckCircle2,
  Clock4,
  Building2,
  User,
  Mail,
  Phone,
  Lock,
  Eye,
  EyeOff,
  ArrowRight,
  ArrowLeft,
  Sparkles,
  Globe,
  Briefcase,
  MapPin,
} from 'lucide-react';
import { useAppDispatch } from '../store/hooks';
import { registerSuccess } from '../features/auth/authSlice';
import { authApi, type RegisterPayload } from '../api/authApi';
import '../styles/auth.css';

const businessTypes = [
  'Clinic',
  'Hospital',
  'Retail Store',
  'Salon',
  'Pharmacy',
  'Laboratory',
  'Other',
];

export default function RegisterScreen() {
  const dispatch = useAppDispatch();
  const navigate = useNavigate();

  const [form, setForm] = useState<RegisterPayload>({
    business_name: '',
    business_type: '',
    owner_name: '',
    email: '',
    phone: '',
    password: '',
    city: '',
    country: '',
  });
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [agreeTerms, setAgreeTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  const set = (key: keyof RegisterPayload, val: string) =>
    setForm((prev: RegisterPayload) => ({ ...prev, [key]: val }));

  const validate = (): string | null => {
    if (!form.business_name.trim()) return 'Business name is required';
    if (!form.business_type) return 'Please select a business type';
    if (!form.owner_name.trim()) return 'Owner name is required';
    if (!form.email.trim()) return 'Email is required';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) return 'Invalid email address';
    if (!form.phone.trim()) return 'Phone number is required';
    if (!form.password) return 'Password is required';
    if (form.password.length < 6) return 'Password must be at least 6 characters';
    if (form.password !== confirmPassword) return 'Passwords do not match';
    if (!agreeTerms) return 'You must agree to the terms';
    return null;
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setErrorMsg('');

    const err = validate();
    if (err) {
      setErrorMsg(err);
      toast.error(err);
      return;
    }

    try {
      setLoading(true);
      const res = await authApi.register(form);
      const { token, business } = res.data;
      dispatch(registerSuccess({ token, business }));
      toast.success('Account created! Redirecting…');
      navigate('/dashboard', { replace: true });
    } catch (err: any) {
      const msg =
        err?.response?.data?.message ||
        err?.response?.data?.error ||
        'Registration failed. Please try again.';
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
          <Link to="/login" className="auth-header__back-btn" aria-label="Back to login">
            <ArrowLeft size={18} />
          </Link>
          <div className="auth-header__logo-box auth-header__logo-box--small">
            <Calendar size={20} color="#fff" />
          </div>
          <div>
            <div className="auth-header__title" style={{ fontSize: 16 }}>
              IQ Store
            </div>
            <div className="auth-header__subtitle">NEW BUSINESS ACCOUNT</div>
          </div>
        </div>
        <Link to="/login" className="auth-header__action-btn">
          <ArrowLeft size={14} />
          Sign In Instead
        </Link>
      </header>

      {/* Content */}
      <div className="auth-content">
        <div className="auth-content__inner">
          <div className="auth-layout-row auth-layout-row--register">
            {/* Left hero */}
            <div className="auth-hero-col">
              <div className="hero-badge">
                <Sparkles size={12} />
                GET STARTED FREE
              </div>
              <h1 className="hero-headline">
                Build Your<br />
                Business Terminal
              </h1>
              <p className="hero-subtitle">
                Create your business account to access the full suite of clinic
                and retail management tools. Setup takes less than 2 minutes.
              </p>
              <div className="hero-features">
                <div className="hero-feature-card">
                  <div
                    className="hero-feature-icon"
                    style={{ background: 'rgba(180, 41, 7, 0.1)' }}
                  >
                    <Calendar size={20} color="var(--primary)" />
                  </div>
                  <div className="hero-feature-title">Smart Scheduling</div>
                  <div className="hero-feature-desc">
                    AI-powered appointment management with conflict detection.
                  </div>
                </div>
                <div className="hero-feature-card">
                  <div
                    className="hero-feature-icon"
                    style={{ background: 'rgba(0, 108, 73, 0.1)' }}
                  >
                    <Zap size={20} color="var(--tertiary)" />
                  </div>
                  <div className="hero-feature-title">Instant POS</div>
                  <div className="hero-feature-desc">
                    Lightning-fast checkout with integrated inventory tracking.
                  </div>
                </div>
              </div>
              <div className="hero-trust-badges">
                <span className="hero-trust-badge">
                  <CheckCircle2 size={14} color="var(--tertiary)" />
                  Free 14-day Trial
                </span>
                <span className="hero-trust-badge">
                  <CheckCircle2 size={14} color="var(--tertiary)" />
                  No Credit Card
                </span>
                <span className="hero-trust-badge">
                  <Clock4 size={14} color="var(--tertiary)" />
                  2-min Setup
                </span>
              </div>
            </div>

            {/* Register Card */}
            <div className="auth-card-col auth-card-col--register">
              <form className="auth-card auth-card--register" onSubmit={handleSubmit}>
                <div className="auth-card__header">
                  <div className="auth-card__icon-box">
                    <UserPlus size={22} color="#fff" />
                  </div>
                </div>

                <h2 className="auth-card__title">Create Business Account</h2>
                <p className="auth-card__desc">
                  Fill in your business details to get started
                </p>

                {errorMsg && (
                  <div className="auth-error-box">
                    <Shield size={14} color="var(--error)" />
                    <span className="auth-error-box__text">{errorMsg}</span>
                  </div>
                )}

                <div className="auth-form auth-form--register">
                  {/* Business name + type */}
                  <div className="field-row">
                    <div className="field-group">
                      <label className="field-label">
                        <Building2 size={14} className="field-label__icon" />
                        Business Name
                      </label>
                      <input
                        id="reg-business-name"
                        type="text"
                        className="auth-input"
                        placeholder="My Clinic / Store"
                        value={form.business_name}
                        onChange={(e) => set('business_name', e.target.value)}
                      />
                    </div>
                    <div className="field-group">
                      <label className="field-label">
                        <Briefcase size={14} className="field-label__icon" />
                        Business Type
                      </label>
                      <select
                        id="reg-business-type"
                        className="auth-select"
                        value={form.business_type}
                        onChange={(e) => set('business_type', e.target.value)}
                      >
                        <option value="" disabled>
                          Select type
                        </option>
                        {businessTypes.map((t) => (
                          <option key={t} value={t}>
                            {t}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>

                  {/* Owner name + Email */}
                  <div className="field-row">
                    <div className="field-group">
                      <label className="field-label">
                        <User size={14} className="field-label__icon" />
                        Owner Name
                      </label>
                      <input
                        id="reg-owner-name"
                        type="text"
                        className="auth-input"
                        placeholder="John Doe"
                        value={form.owner_name}
                        onChange={(e) => set('owner_name', e.target.value)}
                      />
                    </div>
                    <div className="field-group">
                      <label className="field-label">
                        <Mail size={14} className="field-label__icon" />
                        Email Address
                      </label>
                      <input
                        id="reg-email"
                        type="email"
                        className="auth-input"
                        placeholder="owner@business.com"
                        value={form.email}
                        onChange={(e) => set('email', e.target.value)}
                      />
                    </div>
                  </div>

                  {/* Phone + City */}
                  <div className="field-row">
                    <div className="field-group">
                      <label className="field-label">
                        <Phone size={14} className="field-label__icon" />
                        Phone Number
                      </label>
                      <input
                        id="reg-phone"
                        type="tel"
                        className="auth-input"
                        placeholder="+91 9876543210"
                        value={form.phone}
                        onChange={(e) => set('phone', e.target.value)}
                      />
                    </div>
                    <div className="field-group">
                      <label className="field-label">
                        <MapPin size={14} className="field-label__icon" />
                        City
                      </label>
                      <input
                        id="reg-city"
                        type="text"
                        className="auth-input"
                        placeholder="Chennai"
                        value={form.city}
                        onChange={(e) => set('city', e.target.value)}
                      />
                    </div>
                  </div>

                  {/* Password + Confirm */}
                  <div className="field-row">
                    <div className="field-group">
                      <label className="field-label">
                        <Lock size={14} className="field-label__icon" />
                        Password
                      </label>
                      <div className="password-wrapper">
                        <input
                          id="reg-password"
                          type={showPassword ? 'text' : 'password'}
                          className="auth-input"
                          placeholder="Min 6 characters"
                          value={form.password}
                          onChange={(e) => set('password', e.target.value)}
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
                    <div className="field-group">
                      <label className="field-label">
                        <Lock size={14} className="field-label__icon" />
                        Confirm Password
                      </label>
                      <div className="password-wrapper">
                        <input
                          id="reg-confirm-password"
                          type={showConfirm ? 'text' : 'password'}
                          className="auth-input"
                          placeholder="Re-enter password"
                          value={confirmPassword}
                          onChange={(e) => setConfirmPassword(e.target.value)}
                        />
                        <button
                          type="button"
                          className="password-toggle"
                          onClick={() => setShowConfirm(!showConfirm)}
                          tabIndex={-1}
                        >
                          {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Terms */}
                  <div className="auth-terms">
                    <input
                      id="terms"
                      type="checkbox"
                      checked={agreeTerms}
                      onChange={(e) => setAgreeTerms(e.target.checked)}
                    />
                    <label htmlFor="terms">
                      I agree to the{' '}
                      <a href="#terms">Terms of Service</a> and{' '}
                      <a href="#privacy">Privacy Policy</a>
                    </label>
                  </div>

                  {/* Submit */}
                  <button
                    id="register-submit"
                    type="submit"
                    className="auth-submit-btn"
                    disabled={loading}
                  >
                    {loading ? (
                      <span className="auth-submit-spinner" />
                    ) : (
                      <>
                        Create Account &amp; Launch
                        <ArrowRight size={18} />
                      </>
                    )}
                  </button>
                </div>

                <div className="auth-switch">
                  <span>Already have an account?</span>
                  <Link to="/login" className="auth-switch__link">
                    Sign in to your terminal
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
