import { useState, type FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../lib/api';
import { Loader2, CheckCircle } from 'lucide-react';

export default function CompleteRegistrationPage() {
  const [params] = useSearchParams();
  const navigate  = useNavigate();
  const token     = params.get('token') ?? '';

  const [form, setForm] = useState({
    password: '', confirmPassword: '',
    personalPhone: '', dateOfBirth: '', homeAddress: '',
  });
  const [error,   setError]   = useState('');
  const [loading, setLoading] = useState(false);
  const [done,    setDone]    = useState(false);

  if (!token) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center p-4">
        <div className="card max-w-sm w-full text-center space-y-3">
          <p className="text-myraba-error font-semibold">Invalid invitation link</p>
          <p className="text-myraba-second text-sm">This link is missing a token. Please use the link from your invitation email.</p>
        </div>
      </div>
    );
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');

    if (form.password.length < 8) {
      setError('Password must be at least 8 characters'); return;
    }
    if (form.password !== form.confirmPassword) {
      setError('Passwords do not match'); return;
    }

    setLoading(true);
    try {
      const { data } = await api.post('/admin/auth/complete-registration', {
        token,
        password:      form.password,
        personalPhone: form.personalPhone.trim() || null,
        dateOfBirth:   form.dateOfBirth.trim()   || null,
        homeAddress:   form.homeAddress.trim()   || null,
      });

      // Auto-login: store the returned token
      localStorage.setItem('myraba_admin_token',    data.token);
      localStorage.setItem('myraba_admin_role',     data.role);
      localStorage.setItem('myraba_admin_staffid',  data.staffId);
      localStorage.setItem('myraba_admin_fullname', data.fullName);

      setDone(true);
      setTimeout(() => navigate('/'), 2000);
    } catch (err: any) {
      setError(err.response?.data?.message ?? 'Something went wrong. The link may have expired.');
    } finally {
      setLoading(false);
    }
  }

  if (done) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center p-4">
        <div className="card max-w-sm w-full text-center space-y-4">
          <CheckCircle className="mx-auto text-myraba-success" size={48} />
          <p className="text-white font-semibold text-lg">Registration complete!</p>
          <p className="text-myraba-second text-sm">Taking you to the dashboard…</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-brand/10 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-md relative">
        <div className="flex flex-col items-center gap-3 mb-8">
          <div className="w-14 h-14 rounded-2xl bg-brand flex items-center justify-center text-white font-bold text-2xl shadow-xl shadow-brand/30">
            M
          </div>
          <div className="text-center">
            <p className="text-white font-bold text-xl">Welcome to Myraba</p>
            <p className="text-myraba-hint text-sm mt-1">Complete your staff registration</p>
          </div>
        </div>

        <div className="card space-y-5">
          {error && (
            <div className="bg-myraba-error/10 border border-myraba-error/30 text-myraba-error text-sm rounded-lg px-4 py-3">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <p className="text-myraba-second text-xs uppercase tracking-wider font-medium">Set your password</p>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-myraba-second text-xs block mb-1">Password <span className="text-myraba-error">*</span></label>
                <input
                  className="input"
                  type="password"
                  placeholder="Min 8 characters"
                  value={form.password}
                  onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
                  required
                />
              </div>
              <div>
                <label className="text-myraba-second text-xs block mb-1">Confirm password <span className="text-myraba-error">*</span></label>
                <input
                  className="input"
                  type="password"
                  placeholder="Repeat password"
                  value={form.confirmPassword}
                  onChange={e => setForm(f => ({ ...f, confirmPassword: e.target.value }))}
                  required
                />
              </div>
            </div>

            <p className="text-myraba-second text-xs uppercase tracking-wider font-medium pt-2">Personal details</p>

            <div>
              <label className="text-myraba-second text-xs block mb-1">Phone number (personal)</label>
              <input
                className="input"
                type="tel"
                placeholder="08012345678"
                value={form.personalPhone}
                onChange={e => setForm(f => ({ ...f, personalPhone: e.target.value }))}
              />
            </div>

            <div>
              <label className="text-myraba-second text-xs block mb-1">Date of birth</label>
              <input
                className="input"
                type="date"
                value={form.dateOfBirth}
                onChange={e => setForm(f => ({ ...f, dateOfBirth: e.target.value }))}
              />
            </div>

            <div>
              <label className="text-myraba-second text-xs block mb-1">Home address</label>
              <input
                className="input"
                placeholder="Street, City, State"
                value={form.homeAddress}
                onChange={e => setForm(f => ({ ...f, homeAddress: e.target.value }))}
              />
            </div>

            <button
              type="submit"
              className="btn-primary w-full flex items-center justify-center gap-2 py-3 mt-2 rounded-xl text-base"
              disabled={loading}
            >
              {loading && <Loader2 size={16} className="animate-spin" />}
              {loading ? 'Activating account…' : 'Complete registration'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
