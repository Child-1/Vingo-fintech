import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatNumber, formatDate } from '../lib/utils';
import { Star, Zap, AlertTriangle } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function PointsPage() {
  const qc = useQueryClient();
  const { isSuperAdmin } = useAuth();

  const [grantForm, setGrantForm] = useState({ myrabaHandle: '', points: '', reason: '' });
  const [bulkConfirm, setBulkConfirm] = useState(false);

  const { data: stats } = useQuery({
    queryKey: ['points-stats'],
    queryFn: () => api.get('/api/admin/points/stats').then(r => r.data),
  });

  const { data: leaderboard } = useQuery({
    queryKey: ['points-leaderboard'],
    queryFn: () => api.get('/api/admin/points/leaderboard').then(r => r.data),
  });

  const grantPoints = useMutation({
    mutationFn: (payload: typeof grantForm) =>
      api.post('/api/admin/points/grant', { ...payload, points: Number(payload.points) }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['points-stats'] });
      qc.invalidateQueries({ queryKey: ['points-leaderboard'] });
      setGrantForm({ myrabaHandle: '', points: '', reason: '' });
    },
  });

  const bulkConvert = useMutation({
    mutationFn: () => api.post('/api/admin/points/convert-all'),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['points-stats'] });
      setBulkConfirm(false);
    },
  });

  const leaders = Array.isArray(leaderboard) ? leaderboard : (leaderboard?.users ?? []);

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold text-white">Points</h1>
        <p className="text-myraba-hint text-sm">Grant rewards and manage year-end conversions</p>
      </div>

      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {[
            { label: 'Total Points Issued',    value: formatNumber(stats.totalPointsIssued ?? 0), accent: 'text-brand' },
            { label: 'Total Points Redeemed',  value: formatNumber(stats.totalRedeemed ?? 0),     accent: 'text-myraba-success' },
            { label: 'Users with Points',      value: formatNumber(stats.usersWithPoints ?? 0),   accent: 'text-white' },
          ].map(({ label, value, accent }) => (
            <div key={label} className="card">
              <p className="text-myraba-second text-xs">{label}</p>
              <p className={`text-2xl font-bold mt-1 ${accent}`}>{value}</p>
            </div>
          ))}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* Grant points form */}
        <div className="card space-y-4">
          <div className="flex items-center gap-2">
            <Star size={16} className="text-brand" />
            <h2 className="text-white font-medium text-sm">Grant Points to User</h2>
          </div>
          <div className="space-y-3">
            <div>
              <label className="text-myraba-second text-xs block mb-1">MyrabaTag</label>
              <input className="input" placeholder="@username" value={grantForm.myrabaHandle}
                onChange={e => setGrantForm(f => ({ ...f, myrabaHandle: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Points</label>
              <input className="input" type="number" placeholder="100" value={grantForm.points}
                onChange={e => setGrantForm(f => ({ ...f, points: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Reason</label>
              <input className="input" placeholder="Promo, referral, goodwill…" value={grantForm.reason}
                onChange={e => setGrantForm(f => ({ ...f, reason: e.target.value }))} />
            </div>
          </div>
          <button className="btn-primary w-full"
            disabled={!grantForm.myrabaHandle || !grantForm.points || grantPoints.isPending}
            onClick={() => grantPoints.mutate(grantForm)}>
            {grantPoints.isPending ? 'Granting…' : 'Grant Points'}
          </button>
          {grantPoints.isSuccess && (
            <p className="text-myraba-success text-xs">Points granted successfully.</p>
          )}
          {grantPoints.isError && (
            <p className="text-myraba-error text-xs">Failed. Check the MyrabaTag and try again.</p>
          )}
        </div>

        {/* Year-end conversion */}
        {isSuperAdmin && (
          <div className="card space-y-4">
            <div className="flex items-center gap-2">
              <Zap size={16} className="text-myraba-gold" />
              <h2 className="text-white font-medium text-sm">Year-End Points Conversion</h2>
            </div>
            <p className="text-myraba-second text-sm">
              Convert all users' yearly points to wallet credit. This runs automatically at year-end but can be triggered manually.
            </p>

            {!bulkConfirm ? (
              <button className="btn-danger w-full" onClick={() => setBulkConfirm(true)}>
                Trigger Bulk Conversion
              </button>
            ) : (
              <div className="space-y-3">
                <div className="flex items-start gap-2 bg-myraba-gold/10 border border-myraba-gold/30 rounded-lg p-3">
                  <AlertTriangle size={16} className="text-myraba-gold flex-shrink-0 mt-0.5" />
                  <p className="text-myraba-gold text-xs">
                    This will convert all users' current-year points to wallet credit. This action is irreversible.
                  </p>
                </div>
                <div className="flex gap-2">
                  <button className="btn-ghost flex-1" onClick={() => setBulkConfirm(false)}>Cancel</button>
                  <button className="btn-danger flex-1" disabled={bulkConvert.isPending}
                    onClick={() => bulkConvert.mutate()}>
                    {bulkConvert.isPending ? 'Converting…' : 'Confirm Convert All'}
                  </button>
                </div>
              </div>
            )}
            {bulkConvert.isSuccess && (
              <p className="text-myraba-success text-xs">Bulk conversion completed.</p>
            )}
          </div>
        )}
      </div>

      {/* Leaderboard */}
      <div className="card p-0 overflow-hidden">
        <div className="px-4 py-3 border-b border-surface-border">
          <h2 className="text-white font-medium text-sm">Top Points Holders</h2>
        </div>
        <table className="data-table">
          <thead>
            <tr><th>#</th><th>User</th><th>This Year</th><th>All-Time</th><th>Last Updated</th></tr>
          </thead>
          <tbody>
            {leaders.length === 0 ? (
              <tr><td colSpan={5} className="text-center text-myraba-hint py-8">No data yet.</td></tr>
            ) : leaders.map((u: any, i: number) => (
              <tr key={u.id ?? i}>
                <td className="text-myraba-hint font-mono text-xs">{i + 1}</td>
                <td>
                  <p className="text-white text-sm">{u.fullName}</p>
                  <p className="text-myraba-hint text-xs">@{u.myrabaHandle}</p>
                </td>
                <td className="text-brand font-semibold">{formatNumber(u.thisYear ?? 0)}</td>
                <td className="text-myraba-second">{formatNumber(u.allTime ?? u.totalLifetime ?? 0)}</td>
                <td className="text-myraba-hint text-xs">{u.updatedAt ? formatDate(u.updatedAt) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
