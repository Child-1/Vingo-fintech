import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate, roleBadge } from '../lib/utils';
import { useAuth } from '../context/AuthContext';
import { Users, Plus, RotateCcw, ShieldOff, X, Loader2 } from 'lucide-react';

interface StaffMember {
  id: number;
  myrabaHandle: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  role: string;
  status: string;
  forcePasswordChange: boolean;
  createdAt: string;
}

const ROLE_OPTIONS = ['STAFF', 'ADMIN'];

export default function StaffPage() {
  const qc = useQueryClient();
  const { isSuperAdmin, role: myRole } = useAuth();
  const canCreate = myRole === 'ADMIN' || myRole === 'SUPER_ADMIN';

  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    fullName: '', email: '', phone: '', myrabaHandle: '', role: 'STAFF',
  });
  const [confirmRevoke, setConfirmRevoke] = useState<StaffMember | null>(null);
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; msg: string } | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['staff-list'],
    queryFn: () => api.get('/api/admin/management/staff').then(r => r.data),
  });

  const createStaff = useMutation({
    mutationFn: () => api.post('/api/admin/management/staff', form),
    onSuccess: (res) => {
      qc.invalidateQueries({ queryKey: ['staff-list'] });
      setShowForm(false);
      setForm({ fullName: '', email: '', phone: '', myrabaHandle: '', role: 'STAFF' });
      setFeedback({ type: 'success', msg: res.data.message ?? 'Staff account created.' });
      setTimeout(() => setFeedback(null), 6000);
    },
    onError: (err: any) => {
      setFeedback({ type: 'error', msg: err.response?.data?.message ?? 'Failed to create staff.' });
      setTimeout(() => setFeedback(null), 6000);
    },
  });

  const resetPassword = useMutation({
    mutationFn: (id: number) => api.put(`/api/admin/management/staff/${id}/reset-password`),
    onSuccess: () => {
      setFeedback({ type: 'success', msg: 'Temporary password sent to staff email.' });
      setTimeout(() => setFeedback(null), 6000);
    },
    onError: (err: any) => {
      setFeedback({ type: 'error', msg: err.response?.data?.message ?? 'Reset failed.' });
      setTimeout(() => setFeedback(null), 4000);
    },
  });

  const revokeAccess = useMutation({
    mutationFn: (id: number) => api.delete(`/api/admin/management/staff/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['staff-list'] });
      setConfirmRevoke(null);
      setFeedback({ type: 'success', msg: 'Staff access revoked.' });
      setTimeout(() => setFeedback(null), 5000);
    },
    onError: (err: any) => {
      setFeedback({ type: 'error', msg: err.response?.data?.message ?? 'Revoke failed.' });
      setTimeout(() => setFeedback(null), 4000);
    },
  });

  const staff: StaffMember[] = Array.isArray(data) ? data : [];

  const isFormValid = form.fullName.trim() && form.email.trim() && form.myrabaHandle.trim();

  return (
    <div className="p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">Staff Management</h1>
          <p className="text-myraba-hint text-sm mt-0.5">
            {staff.length} team {staff.length === 1 ? 'member' : 'members'} · ADMIN and SUPER_ADMIN can create STAFF · only SUPER_ADMIN can create ADMIN
          </p>
        </div>
        {canCreate && (
          <button className="btn-primary flex items-center gap-2" onClick={() => setShowForm(true)}>
            <Plus size={14} /> Add Staff
          </button>
        )}
      </div>

      {/* Feedback banner */}
      {feedback && (
        <div className={`flex items-center justify-between gap-3 rounded-lg px-4 py-3 text-sm ${
          feedback.type === 'success'
            ? 'bg-myraba-success/10 border border-myraba-success/30 text-myraba-success'
            : 'bg-myraba-error/10 border border-myraba-error/30 text-myraba-error'
        }`}>
          <span>{feedback.msg}</span>
          <button onClick={() => setFeedback(null)} className="opacity-60 hover:opacity-100"><X size={14} /></button>
        </div>
      )}

      {/* Create form */}
      {showForm && (
        <div className="card space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-white font-medium">New Staff Account</h2>
            <button onClick={() => setShowForm(false)} className="text-myraba-hint hover:text-white"><X size={16} /></button>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-myraba-second text-xs block mb-1">Full Name <span className="text-myraba-error">*</span></label>
              <input className="input" placeholder="e.g. Chisom Okafor"
                value={form.fullName} onChange={e => setForm(f => ({ ...f, fullName: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">MyrabaTag <span className="text-myraba-error">*</span></label>
              <input className="input" placeholder="e.g. chisom_ops (no @)"
                value={form.myrabaHandle} onChange={e => setForm(f => ({ ...f, myrabaHandle: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Email <span className="text-myraba-error">*</span></label>
              <input className="input" type="email" placeholder="chisom@myraba.ng"
                value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Phone (optional)</label>
              <input className="input" placeholder="08012345678"
                value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Role</label>
              <select className="input" value={form.role}
                onChange={e => setForm(f => ({ ...f, role: e.target.value }))}>
                {ROLE_OPTIONS.filter(r => r === 'STAFF' || isSuperAdmin).map(r => (
                  <option key={r} value={r}>{r}</option>
                ))}
              </select>
              <p className="text-myraba-hint text-xs mt-1">
                {form.role === 'ADMIN'
                  ? 'ADMIN — full access except balance adjustments and staff creation at ADMIN level'
                  : 'STAFF — read-only: view users, transactions, audit log'}
              </p>
            </div>
          </div>

          <div className="bg-myraba-gold/10 border border-myraba-gold/30 rounded-lg px-4 py-3 text-xs text-myraba-gold">
            A temporary password will be auto-generated and emailed to the staff member. They will be required to change it on first login.
          </div>

          <div className="flex gap-3 pt-1">
            <button className="btn-ghost" onClick={() => setShowForm(false)}>Cancel</button>
            <button className="btn-primary flex items-center gap-2"
              disabled={!isFormValid || createStaff.isPending}
              onClick={() => createStaff.mutate()}>
              {createStaff.isPending && <Loader2 size={14} className="animate-spin" />}
              {createStaff.isPending ? 'Creating…' : 'Create Staff Account'}
            </button>
          </div>
        </div>
      )}

      {/* Staff table */}
      <div className="card p-0 overflow-hidden">
        {isLoading ? (
          <div className="p-8 text-center text-myraba-hint text-sm">Loading…</div>
        ) : staff.length === 0 ? (
          <div className="flex flex-col items-center py-14 text-center">
            <Users size={40} className="text-myraba-hint mb-3" />
            <p className="text-myraba-second font-medium">No staff members yet</p>
            <p className="text-myraba-hint text-sm mt-1">Create the first staff account to get started.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Contact</th>
                  <th>Role</th>
                  <th>Status</th>
                  <th>Joined</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {staff.map(s => (
                  <tr key={s.id}>
                    <td>
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-brand-500/20 flex items-center justify-center text-brand-500 text-xs font-bold flex-shrink-0">
                          {s.fullName[0]}
                        </div>
                        <div>
                          <p className="text-white text-sm font-medium">{s.fullName}</p>
                          <p className="text-myraba-hint text-xs">@{s.myrabaHandle}</p>
                        </div>
                      </div>
                    </td>
                    <td>
                      <p className="text-myraba-second text-xs">{s.email ?? '—'}</p>
                      <p className="text-myraba-hint text-xs">{s.phone ?? ''}</p>
                    </td>
                    <td><span className={roleBadge(s.role)}>{s.role}</span></td>
                    <td>
                      <div className="flex flex-col gap-1">
                        <span className={s.status === 'ACTIVE' ? 'badge-green' : 'badge-red'}>{s.status}</span>
                        {s.forcePasswordChange && (
                          <span className="badge-yellow text-xs">pwd change required</span>
                        )}
                      </div>
                    </td>
                    <td className="text-myraba-hint text-xs">{formatDate(s.createdAt)}</td>
                    <td>
                      <div className="flex items-center gap-2">
                        <button
                          title="Reset password"
                          className="btn-ghost p-1.5 text-myraba-second hover:text-white"
                          disabled={resetPassword.isPending}
                          onClick={() => resetPassword.mutate(s.id)}>
                          <RotateCcw size={14} />
                        </button>
                        {isSuperAdmin && s.role !== 'SUPER_ADMIN' && (
                          <button
                            title="Revoke access"
                            className="btn-ghost p-1.5 text-myraba-hint hover:text-myraba-error"
                            onClick={() => setConfirmRevoke(s)}>
                            <ShieldOff size={14} />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Revoke confirmation dialog */}
      {confirmRevoke && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4" onClick={() => setConfirmRevoke(null)}>
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
          <div className="relative bg-surface-card border border-surface-border rounded-xl p-6 w-full max-w-sm space-y-4"
               onClick={e => e.stopPropagation()}>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-myraba-error/15 flex items-center justify-center flex-shrink-0">
                <ShieldOff size={18} className="text-myraba-error" />
              </div>
              <div>
                <p className="text-white font-semibold text-sm">Revoke access?</p>
                <p className="text-myraba-hint text-xs mt-0.5">@{confirmRevoke.myrabaHandle} · {confirmRevoke.role}</p>
              </div>
            </div>
            <p className="text-myraba-second text-sm">
              This will demote <span className="text-white font-medium">{confirmRevoke.fullName}</span> to a regular USER and suspend their account. This is audited.
            </p>
            <div className="flex gap-3 pt-1">
              <button className="btn-ghost flex-1" onClick={() => setConfirmRevoke(null)}>Cancel</button>
              <button className="btn-danger flex-1 flex items-center justify-center gap-2"
                disabled={revokeAccess.isPending}
                onClick={() => revokeAccess.mutate(confirmRevoke.id)}>
                {revokeAccess.isPending && <Loader2 size={14} className="animate-spin" />}
                {revokeAccess.isPending ? 'Revoking…' : 'Revoke Access'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
