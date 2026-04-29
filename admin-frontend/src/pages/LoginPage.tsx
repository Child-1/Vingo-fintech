import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Loader2 } from 'lucide-react';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate  = useNavigate();
  const [staffId,  setStaffId]  = useState('');
  const [password, setPassword] = useState('');
  const [error,    setError]    = useState('');
  const [loading,  setLoading]  = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(''); setLoading(true);
    const err = await login(staffId.trim(), password);
    setLoading(false);
    if (err) { setError(err); return; }
    navigate('/');
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-brand/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-purple/10 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-sm relative">
        <div className="flex flex-col items-center gap-3 mb-8">
          <div className="w-14 h-14 rounded-2xl bg-brand flex items-center justify-center text-white font-bold text-2xl shadow-xl shadow-brand/30">
            M
          </div>
          <div className="text-center">
            <p className="text-white font-bold text-xl leading-none">Myraba</p>
            <p className="text-myraba-hint text-sm mt-1">Admin Console</p>
          </div>
        </div>

        <div className="card border-surface-border/80">
          <h1 className="text-lg font-bold text-white mb-1">Staff sign in</h1>
          <p className="text-myraba-second text-sm mb-6">Use your Staff ID and password</p>

          {error && (
            <div className="bg-myraba-error/10 border border-myraba-error/30 text-myraba-error text-sm rounded-lg px-4 py-3 mb-4">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-myraba-second text-sm mb-1.5">Staff ID</label>
              <input
                className="input"
                type="text"
                placeholder="e.g. ADM-SUPER-001 or STF-2025-001"
                value={staffId}
                onChange={e => setStaffId(e.target.value)}
                required
                autoFocus
              />
            </div>
            <div>
              <label className="block text-myraba-second text-sm mb-1.5">Password</label>
              <input
                className="input"
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={e => setPassword(e.target.value)}
                required
              />
            </div>
            <button
              type="submit"
              className="btn-primary w-full flex items-center justify-center gap-2 py-3 mt-2 text-base rounded-xl"
              disabled={loading}
            >
              {loading && <Loader2 size={16} className="animate-spin" />}
              {loading ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
        </div>

        <p className="text-center text-myraba-hint text-xs mt-6">
          Myraba Admin · Authorised personnel only
        </p>
      </div>
    </div>
  );
}
