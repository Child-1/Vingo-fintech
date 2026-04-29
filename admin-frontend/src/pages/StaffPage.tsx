import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate, roleBadge } from '../lib/utils';
import { useAuth } from '../context/AuthContext';
import { Users, Plus, Send, ShieldOff, X, Loader2, CheckCircle, Clock } from 'lucide-react';

interface StaffMember {
  id: number;
  staffId: string | null;
  fullName: string;
  email: string | null;
  personalPhone: string | null;
  role: string;
  status: string;
  staffActivated: boolean;
  createdAt: string;
}

const ROLE_OPTIONS = ['STAFF', 'ADMIN'];

export default function StaffPage() {
  const qc = useQueryClient();
  const { isSuperAdmin, role: myRole } = useAuth();
  const canCreate = myRole === 'ADMIN' || myRole === 'SUPER_ADMIN';

  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ fullName: '', email: '', role: 'STAFF' });
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
      setForm({ fullName: '', email: '', role: 'STAFF' });
      setFeedback({ type: 'success', msg: res.data.message ?? 'Invitation sent.' });
      setTimeout(() => setFeedback(null), 8000);
    },
    onError: (err: any) => {
      setFeedback({ type: 'error', msg: err.response?.data?.message ?? 'Failed to create staff.' });
      setTimeout(() => setFeedback(null), 6000);
    },
  });

  const resendInvite = useMutation({
    mutationFn: (id: number) => api.post(`/api/admin/management/staff/${id}/resend-invite`),
    onSuccess: () => {
      setFeedback({ type: 'success', msg: 'Invitation resent successfully.' });
      setTimeout(() => setFeedback(null), 6000);
    },
    onError: (err: any) => {
      setFeedback({ type: 'error', msg: err.response?.data?.message ?? 'Resend failed.' });
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
  const isFormValid = form.fullName.trim() && form.email.trim();

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">Staff Management</h1>
          <p className="text-myraba-hint text-sm mt-0.5">
            {staff.length} team {staff.length === 1 ? 'member' : 'members'} · Staff log in with their Staff ID and password
          </p>
        </div>
        {canCreate && (
          <button className="btn-primary flex items-center gap-2" onClick={() => setShowForm(true)}>
            <Plus size={14} /> Add Staff
          </button>
        )}
      </div>

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

      {showForm && (
        <div className="card space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-white font-medium">Invite New Staff Member</h2>
            <button onClick={() => setShowForm(false)} className="text-myraba-hint hover:text-white"><X size={16} /></button>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-myraba-second text-xs block mb-1">Full Name <span className="text-myraba-error">*</span></label>
              <input className="input" placeholder="e.g. Chisom Okafor"
                value={form.fullName} onChange={e => setForm(f => ({ ...f, fullName: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Work Email <span className="text-myraba-error">*</span></label>
              <input className="input" type="email" placeholder="chisom@myraba.ng"
                value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} />
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
                  ? 'ADMIN — full access except balance adjustments'
                  : 'STAFF — read-only: view users, transactions, audit log'}
              </p>
            </div>
          </div>

          <div className="bg-brand/10 border border-brand/20 rounded-lg px-4 py-3 text-xs text-myraba-second">
            A Staff ID will be auto-generated and an invitation email will be sent. The staff member must click the link to set their password and complete registration before they can log in.
          </div>

          <div className="flex gap-3 pt-1">
            <button className="btn-ghost" onClick={() => setShowForm(false)}>Cancel</button>
            <button className="btn-primary flex items-center gap-2"
              disabled={!isFormValid || createStaff.isPending}
              onClick={() => createStaff.mutate()}>
              {createStaff.isPending && <Loader2 size={14} className="animate-spin" />}
              {createStaff.isPending ? 'Sending invite…' : 'Send Invitation'}
            </button>
          </div>
        </div>
      )}

      <div className="card p-0 overflow-hidden">
        {isLoading ? (
          <div className="p-8 text-center text-myraba-hint text-sm">Loading…</div>
        ) : staff.length === 0 ? (
          <div className="flex flex-col items-center py-14 text-center">
            <Users size={40} className="text-myraba-hint mb-3" />
            <p className="text-myraba-second font-medium">No staff members yet</p>
            <p className="text-myraba-hint text-sm mt-1">Invite the first staff member to get started.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Staff ID</th>
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
                          <p className="text-myraba-hint text-xs">{s.email ?? '—'}</p>
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className="font-mono text-myraba-second text-xs">{s.staffId ?? '—'}</span>
                    </td>
                    <td><span className={roleBadge(s.role)}>{s.role}</span></td>
                    <td>
                      <div className="flex flex-col gap-1">
                        <span className={s.status === 'ACTIVE' ? 'badge-green' : 'badge-red'}>{s.status}</span>
                        {!s.staffActivated && (
                          <span className="badge-yellow flex items-center gap-1 text-xs">
                            <Clock size={10} /> invite pending
                          </span>
                        )}
                        {s.staffActivated && (
                          <span className="text-myraba-hint flex items-center gap-1 text-xs">
                            <CheckCircle size={10} /> registered
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="text-myraba-hint text-xs">{formatDate(s.createdAt)}</td>
                    <td>
                      <div className="flex items-center gap-2">
                        {!s.staffActivated && (
                          <button
                            title="Resend invitation"
                            className="btn-ghost p-1.5 text-myraba-second hover:text-white"
                            disabled={resendInvite.isPending}
                            onClick={() => resendInvite.mutate(s.id)}>
                            <Send size={14} />
                          </button>
                        )}
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
                <p className="text-myraba-hint text-xs mt-0.5">{confirmRevoke.staffId} · {confirmRevoke.role}</p>
              </div>
            </div>
            <p className="text-myraba-second text-sm">
              This will suspend <span className="text-white font-medium">{confirmRevoke.fullName}</span>'s account.
              They will no longer be able to log into the admin portal. This action is audited.
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
