import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import type { AdminUser } from '../types';
import { formatDate, formatNaira, roleBadge, accountStatusBadge, kycBadge } from '../lib/utils';
import { Search, ChevronLeft, ChevronRight, X } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const PAGE_SIZE = 20;

export default function UsersPage() {
  const qc = useQueryClient();
  const { isSuperAdmin, role } = useAuth();
  const canManage = role === 'ADMIN' || role === 'SUPER_ADMIN';

  const [search,    setSearch]    = useState('');
  const [status,    setStatus]    = useState('');
  const [kycFilter, setKycFilter] = useState('');
  const [page,      setPage]      = useState(0);
  const [selected,  setSelected]  = useState<AdminUser | null>(null);

  const params: Record<string, string> = {
    page: String(page), size: String(PAGE_SIZE),
    ...(search    && { search }),
    ...(status    && { status }),
    ...(kycFilter && { kycStatus: kycFilter }),
  };

  const { data, isLoading } = useQuery({
    queryKey: ['admin-users', params],
    queryFn: () => api.get('/api/admin/users', { params }).then(r => r.data),
  });

  const { data: userStats } = useQuery({
    queryKey: ['user-stats-overview'],
    queryFn: () => api.get('/api/admin/users/stats/overview').then(r => r.data),
  });

  const { data: userTxStats } = useQuery({
    queryKey: ['user-tx-stats', selected?.id],
    queryFn: () => api.get(`/api/admin/users/${selected!.id}/stats`).then(r => r.data),
    enabled: !!selected,
  });

  const updateRole = useMutation({
    mutationFn: ({ id, role }: { id: number; role: string }) =>
      api.put(`/api/admin/users/${id}/role`, { role }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['admin-users'] }); },
  });

  const updateKyc = useMutation({
    mutationFn: ({ id, status }: { id: number; status: string }) =>
      api.put(`/api/admin/users/${id}/kyc`, { status }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  });

  const freezeUser = useMutation({
    mutationFn: (id: number) => api.post(`/api/admin/users/${id}/freeze`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  });

  const suspendUser = useMutation({
    mutationFn: (id: number) => api.post(`/api/admin/users/${id}/suspend`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  });

  const activateUser = useMutation({
    mutationFn: (id: number) => api.post(`/api/admin/users/${id}/activate`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-users'] }),
  });

  const users: AdminUser[] = data?.users ?? [];
  const total: number      = data?.total ?? 0;
  const totalPages = Math.ceil(total / PAGE_SIZE);

  return (
    <div className="p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">Users</h1>
          <p className="text-myraba-hint text-sm">
            {total ? `${total.toLocaleString()} total users` : 'Loading…'}
          </p>
        </div>
        {userStats && (
          <div className="flex gap-4 text-center text-sm">
            <div><p className="text-myraba-second">Active</p><p className="font-semibold">{userStats.activeUsers ?? '—'}</p></div>
            <div><p className="text-myraba-second">KYC'd</p><p className="font-semibold text-myraba-success">{userStats.kycApproved ?? '—'}</p></div>
            <div><p className="text-myraba-second">Frozen</p><p className="font-semibold text-myraba-error">{userStats.frozenUsers ?? '—'}</p></div>
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-myraba-hint" />
          <input className="input pl-8" placeholder="Search name, MyrabaTag, phone…"
            value={search} onChange={e => { setSearch(e.target.value); setPage(0); }} />
        </div>
        <select className="input w-auto" value={status} onChange={e => { setStatus(e.target.value); setPage(0); }}>
          <option value="">All statuses</option>
          <option value="ACTIVE">Active</option>
          <option value="SUSPENDED">Suspended</option>
          <option value="FROZEN">Frozen</option>
        </select>
        <select className="input w-auto" value={kycFilter} onChange={e => { setKycFilter(e.target.value); setPage(0); }}>
          <option value="">All KYC</option>
          <option value="NONE">None</option>
          <option value="PENDING">Pending</option>
          <option value="APPROVED">Approved</option>
          <option value="REJECTED">Rejected</option>
        </select>
      </div>

      {/* Table */}
      <div className="card p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>User</th><th>Phone / Email</th><th>Account#</th>
                <th>Role</th><th>KYC</th><th>Status</th><th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {isLoading
                ? Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>
                    {Array.from({ length: 7 }).map((_, j) => (
                      <td key={j}><div className="h-4 bg-surface-elevated rounded animate-pulse w-20" /></td>
                    ))}
                  </tr>
                ))
                : users.map(u => (
                  <tr key={u.id} onClick={() => setSelected(u)} className="cursor-pointer">
                    <td>
                      <div>
                        <p className="text-white font-medium text-sm">{u.fullName}</p>
                        <p className="text-myraba-hint text-xs">@{u.myrabaHandle}</p>
                      </div>
                    </td>
                    <td className="text-myraba-second text-xs">{u.phone ?? u.email ?? '—'}</td>
                    <td className="font-mono text-myraba-second text-xs">{u.accountNumber}</td>
                    <td><span className={roleBadge(u.role)}>{u.role}</span></td>
                    <td><span className={kycBadge(u.kycStatus)}>{u.kycStatus}</span></td>
                    <td><span className={accountStatusBadge(u.accountStatus)}>{u.accountStatus}</span></td>
                    <td className="text-myraba-hint text-xs">{formatDate(u.createdAt)}</td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="flex items-center justify-between px-4 py-3 border-t border-surface-border">
          <p className="text-myraba-hint text-xs">
            Showing {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} of {total}
          </p>
          <div className="flex gap-2">
            <button className="btn-ghost px-2 py-1" disabled={page === 0} onClick={() => setPage(p => p - 1)}>
              <ChevronLeft size={16} />
            </button>
            <span className="text-myraba-second text-sm px-2 py-1">{page + 1} / {totalPages || 1}</span>
            <button className="btn-ghost px-2 py-1" disabled={page >= totalPages - 1} onClick={() => setPage(p => p + 1)}>
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      </div>

      {/* ── User detail drawer ── */}
      {selected && (
        <div className="fixed inset-0 z-50 flex" onClick={() => setSelected(null)}>
          <div className="flex-1 bg-black/50 backdrop-blur-sm" />
          <div className="w-[480px] bg-surface-card border-l border-surface-border overflow-y-auto"
               onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 py-4 border-b border-surface-border sticky top-0 bg-surface-card z-10">
              <h2 className="font-semibold text-white">User Detail</h2>
              <button onClick={() => setSelected(null)} className="text-myraba-second hover:text-white">
                <X size={18} />
              </button>
            </div>

            <div className="p-6 space-y-6">
              {/* Profile */}
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-brand/20 flex items-center justify-center text-brand font-bold text-lg">
                  {selected.fullName[0]}
                </div>
                <div>
                  <p className="text-white font-semibold">{selected.fullName}</p>
                  <p className="text-myraba-second text-sm">@{selected.myrabaHandle}</p>
                </div>
              </div>

              {/* Stats */}
              {userTxStats && (
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-surface-elevated rounded-lg p-3">
                    <p className="text-myraba-second text-xs">Sent volume</p>
                    <p className="text-white font-semibold text-sm mt-1">{formatNaira(userTxStats.transactions?.sentVolume ?? 0)}</p>
                  </div>
                  <div className="bg-surface-elevated rounded-lg p-3">
                    <p className="text-myraba-second text-xs">Received volume</p>
                    <p className="text-white font-semibold text-sm mt-1">{formatNaira(userTxStats.transactions?.receivedVolume ?? 0)}</p>
                  </div>
                </div>
              )}

              {/* Info grid */}
              <div className="space-y-3 text-sm">
                {[
                  ['Phone',    selected.phone ?? '—'],
                  ['Email',    selected.email ?? '—'],
                  ['Account#', selected.accountNumber],
                  ['Joined',   formatDate(selected.createdAt)],
                ].map(([k, v]) => (
                  <div key={k} className="flex justify-between">
                    <span className="text-myraba-hint">{k}</span>
                    <span className="text-white font-mono text-xs">{v}</span>
                  </div>
                ))}
              </div>

              {/* Actions — only ADMIN/SUPER_ADMIN */}
              {canManage && (
                <div className="space-y-3">
                  <p className="text-myraba-second text-xs uppercase tracking-wider">Actions</p>

                  {/* Role */}
                  <div>
                    <label className="text-myraba-second text-xs mb-1.5 block">Change role</label>
                    <select className="input"
                      defaultValue={selected.role}
                      onChange={e => updateRole.mutate({ id: selected.id, role: e.target.value })}>
                      {['USER','STAFF','ADMIN', ...(isSuperAdmin ? ['SUPER_ADMIN'] : [])].map(r => (
                        <option key={r} value={r}>{r}</option>
                      ))}
                    </select>
                  </div>

                  {/* KYC */}
                  <div>
                    <label className="text-myraba-second text-xs mb-1.5 block">Update KYC status</label>
                    <select className="input"
                      defaultValue={selected.kycStatus}
                      onChange={e => updateKyc.mutate({ id: selected.id, status: e.target.value })}>
                      {['NONE','PENDING','APPROVED','REJECTED'].map(s => (
                        <option key={s} value={s}>{s}</option>
                      ))}
                    </select>
                  </div>

                  {/* Account status */}
                  <div className="flex gap-2">
                    <button className="btn-primary flex-1" onClick={() => activateUser.mutate(selected.id)}
                      disabled={selected.accountStatus === 'ACTIVE'}>Activate</button>
                    <button className="btn-ghost flex-1" onClick={() => suspendUser.mutate(selected.id)}
                      disabled={selected.accountStatus === 'SUSPENDED'}>Suspend</button>
                    <button className="btn-danger flex-1" onClick={() => freezeUser.mutate(selected.id)}
                      disabled={selected.accountStatus === 'FROZEN'}>Freeze</button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
