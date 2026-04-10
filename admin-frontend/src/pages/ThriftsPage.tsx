import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatNaira, formatDate } from '../lib/utils';
import { PiggyBank, Plus, ToggleLeft, ToggleRight } from 'lucide-react';

export default function ThriftsPage() {
  const qc = useQueryClient();
  const [tab, setTab] = useState<'public' | 'private'>('public');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    name: '', description: '', amount: '', frequency: 'MONTHLY',
    duration: '', memberCount: '',
  });

  /* ── Queries ── */
  const { data: categories, isLoading: loadingCats } = useQuery({
    queryKey: ['admin-thrift-categories'],
    queryFn: () => api.get('/api/admin/thrifts/categories').then(r => r.data),
  });

  const { data: privateThrifts, isLoading: loadingPrivate } = useQuery({
    queryKey: ['admin-private-thrifts'],
    queryFn: () => api.get('/api/admin/thrifts/private').then(r => r.data),
    enabled: tab === 'private',
  });

  /* ── Mutations ── */
  const createCategory = useMutation({
    mutationFn: (payload: typeof form) => api.post('/api/admin/thrifts/categories', {
      ...payload,
      amount: Number(payload.amount),
      duration: Number(payload.duration),
      memberCount: Number(payload.memberCount),
    }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-thrift-categories'] });
      setShowForm(false);
      setForm({ name: '', description: '', amount: '', frequency: 'MONTHLY', duration: '', memberCount: '' });
    },
  });

  const toggleCategory = useMutation({
    mutationFn: ({ id, active }: { id: number; active: boolean }) =>
      active
        ? api.post(`/api/admin/thrifts/categories/${id}/deactivate`)
        : api.post(`/api/admin/thrifts/categories/${id}/activate`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-thrift-categories'] }),
  });

  const cats = Array.isArray(categories) ? categories : (categories?.categories ?? []);
  const privs = Array.isArray(privateThrifts) ? privateThrifts : (privateThrifts?.thrifts ?? []);

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">Thrifts</h1>
          <p className="text-myraba-hint text-sm">Manage public categories &amp; monitor private thrifts</p>
        </div>
        {tab === 'public' && (
          <button className="btn-primary flex items-center gap-2" onClick={() => setShowForm(true)}>
            <Plus size={14} /> New Category
          </button>
        )}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-surface-elevated rounded-lg p-1 w-fit">
        {(['public', 'private'] as const).map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors ${
              tab === t ? 'bg-brand text-white' : 'text-myraba-second hover:text-white'
            }`}>
            {t === 'public' ? 'Public Categories' : 'Private Thrifts'}
          </button>
        ))}
      </div>

      {/* Create category form */}
      {showForm && tab === 'public' && (
        <div className="card space-y-4">
          <h2 className="text-white font-medium">New Thrift Category</h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-myraba-second text-xs block mb-1">Category Name</label>
              <input className="input" placeholder="e.g. Bronze Saver" value={form.name}
                onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Frequency</label>
              <select className="input" value={form.frequency}
                onChange={e => setForm(f => ({ ...f, frequency: e.target.value }))}>
                {['DAILY','WEEKLY','MONTHLY'].map(f => <option key={f} value={f}>{f}</option>)}
              </select>
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Contribution Amount (₦)</label>
              <input className="input" type="number" placeholder="5000" value={form.amount}
                onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Duration (cycles)</label>
              <input className="input" type="number" placeholder="12" value={form.duration}
                onChange={e => setForm(f => ({ ...f, duration: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Max Members</label>
              <input className="input" type="number" placeholder="20" value={form.memberCount}
                onChange={e => setForm(f => ({ ...f, memberCount: e.target.value }))} />
            </div>
            <div>
              <label className="text-myraba-second text-xs block mb-1">Description</label>
              <input className="input" placeholder="Short description" value={form.description}
                onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
            </div>
          </div>
          <div className="flex gap-3 pt-1">
            <button className="btn-ghost" onClick={() => setShowForm(false)}>Cancel</button>
            <button className="btn-primary"
              disabled={!form.name || !form.amount || !form.duration || !form.memberCount || createCategory.isPending}
              onClick={() => createCategory.mutate(form)}>
              {createCategory.isPending ? 'Creating…' : 'Create Category'}
            </button>
          </div>
        </div>
      )}

      {/* Public categories */}
      {tab === 'public' && (
        <div className="space-y-3">
          {loadingCats && <p className="text-myraba-hint">Loading…</p>}
          {!loadingCats && cats.length === 0 && (
            <div className="card flex flex-col items-center py-12 text-center">
              <PiggyBank size={40} className="text-myraba-hint mb-3" />
              <p className="text-myraba-second">No thrift categories yet.</p>
            </div>
          )}
          {cats.map((c: any) => (
            <div key={c.id} className="card flex items-center justify-between gap-4">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <span className={`badge ${c.active ? 'badge-green' : 'badge-gray'}`}>
                    {c.active ? 'ACTIVE' : 'INACTIVE'}
                  </span>
                  <span className="badge badge-orange">{c.frequency}</span>
                </div>
                <p className="text-white font-medium text-sm">{c.name}</p>
                {c.description && <p className="text-myraba-hint text-xs mt-0.5">{c.description}</p>}
                <div className="flex gap-4 mt-2 text-xs text-myraba-hint">
                  <span>Contribution: <span className="text-myraba-second">{formatNaira(c.amount)}</span></span>
                  <span>Duration: <span className="text-myraba-second">{c.duration} cycles</span></span>
                  <span>Members: <span className="text-myraba-second">{c.memberCount} max</span></span>
                </div>
              </div>
              <button
                className={`btn-ghost flex items-center gap-1.5 text-xs ${c.active ? 'text-myraba-error' : 'text-myraba-success'}`}
                onClick={() => toggleCategory.mutate({ id: c.id, active: c.active })}>
                {c.active ? <ToggleRight size={16} /> : <ToggleLeft size={16} />}
                {c.active ? 'Deactivate' : 'Activate'}
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Private thrifts */}
      {tab === 'private' && (
        <div className="space-y-3">
          {loadingPrivate && <p className="text-myraba-hint">Loading…</p>}
          {!loadingPrivate && privs.length === 0 && (
            <div className="card flex flex-col items-center py-12 text-center">
              <PiggyBank size={40} className="text-myraba-hint mb-3" />
              <p className="text-myraba-second">No private thrifts found.</p>
            </div>
          )}
          {privs.map((p: any) => (
            <div key={p.id} className="card">
              <div className="flex items-center justify-between mb-2">
                <div>
                  <p className="text-white font-medium text-sm">{p.name ?? `Thrift #${p.id}`}</p>
                  <p className="text-myraba-hint text-xs">Creator: @{p.creatorHandle} · Code: <span className="font-mono">{p.inviteCode}</span></p>
                </div>
                <span className={`badge ${p.status === 'ACTIVE' ? 'badge-green' : p.status === 'COMPLETED' ? 'badge-purple' : 'badge-gray'}`}>
                  {p.status}
                </span>
              </div>
              <div className="flex gap-4 text-xs text-myraba-hint">
                <span>Members: <span className="text-myraba-second">{p.memberCount}</span></span>
                <span>Amount: <span className="text-myraba-second">{formatNaira(p.amount)}</span></span>
                <span>Positions: <span className="text-myraba-second">{p.positionAssignment}</span></span>
                {p.createdAt && <span>Created: <span className="text-myraba-second">{formatDate(p.createdAt)}</span></span>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
