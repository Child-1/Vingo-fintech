import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate } from '../lib/utils';
import { Megaphone, Trash2, Plus } from 'lucide-react';

const TYPES     = ['INFO','WARNING','PROMOTION','MAINTENANCE','SECURITY'];
const AUDIENCES = ['ALL','KYC_APPROVED','KYC_PENDING','ROLE_USER','ROLE_STAFF'];

export default function BroadcastsPage() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ title: '', body: '', type: 'INFO', audience: 'ALL', expiresAt: '' });

  const { data } = useQuery({
    queryKey: ['broadcasts'],
    queryFn: () => api.get('/api/admin/broadcasts').then(r => r.data),
  });

  const create = useMutation({
    mutationFn: (payload: typeof form) => api.post('/api/admin/broadcasts', payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['broadcasts'] });
      setShowForm(false);
      setForm({ title: '', body: '', type: 'INFO', audience: 'ALL', expiresAt: '' });
    },
  });

  const deactivate = useMutation({
    mutationFn: (id: number) => api.delete(`/api/admin/broadcasts/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['broadcasts'] }),
  });

  const broadcasts = Array.isArray(data) ? data : (data?.broadcasts ?? []);

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">Broadcasts</h1>
          <p className="text-myraba-hint text-sm">Send messages to users</p>
        </div>
        <button className="btn-primary flex items-center gap-2" onClick={() => setShowForm(true)}>
          <Plus size={14} /> New Broadcast
        </button>
      </div>

      {/* Create form */}
      {showForm && (
        <div className="card space-y-4">
          <h2 className="text-white font-medium">New Broadcast</h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-myraba-second text-xs block mb-1">Title</label>
              <input className="input" placeholder="Broadcast title" value={form.title}
                onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-myraba-second text-xs block mb-1">Type</label>
                <select className="input" value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value }))}>
                  {TYPES.map(t => <option key={t} value={t}>{t}</option>)}
                </select>
              </div>
              <div>
                <label className="text-myraba-second text-xs block mb-1">Audience</label>
                <select className="input" value={form.audience} onChange={e => setForm(f => ({ ...f, audience: e.target.value }))}>
                  {AUDIENCES.map(a => <option key={a} value={a}>{a}</option>)}
                </select>
              </div>
            </div>
          </div>
          <div>
            <label className="text-myraba-second text-xs block mb-1">Message</label>
            <textarea className="input h-24 resize-none" placeholder="Broadcast message body…"
              value={form.body} onChange={e => setForm(f => ({ ...f, body: e.target.value }))} />
          </div>
          <div>
            <label className="text-myraba-second text-xs block mb-1">Expires at (optional)</label>
            <input type="datetime-local" className="input w-auto" value={form.expiresAt}
              onChange={e => setForm(f => ({ ...f, expiresAt: e.target.value }))} />
          </div>
          <div className="flex gap-3 pt-1">
            <button className="btn-ghost" onClick={() => setShowForm(false)}>Cancel</button>
            <button className="btn-primary" disabled={!form.title || !form.body || create.isPending}
              onClick={() => create.mutate(form)}>
              {create.isPending ? 'Sending…' : 'Send Broadcast'}
            </button>
          </div>
        </div>
      )}

      {broadcasts.length === 0 && !showForm && (
        <div className="card flex flex-col items-center py-12 text-center">
          <Megaphone size={40} className="text-myraba-hint mb-3" />
          <p className="text-myraba-second">No broadcasts yet.</p>
        </div>
      )}

      <div className="space-y-3">
        {broadcasts.map((b: any) => (
          <div key={b.id} className="card flex items-start justify-between gap-4">
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <span className={`badge ${b.active ? 'badge-green' : 'badge-gray'}`}>{b.active ? 'ACTIVE' : 'INACTIVE'}</span>
                <span className="badge badge-orange">{b.type}</span>
                <span className="badge badge-yellow">{b.audience}</span>
              </div>
              <p className="text-white font-medium text-sm">{b.title}</p>
              <p className="text-myraba-second text-sm mt-1">{b.body}</p>
              <p className="text-myraba-hint text-xs mt-2">{formatDate(b.createdAt)}</p>
            </div>
            {b.active && (
              <button className="btn-ghost text-myraba-error hover:text-myraba-error/80 flex-shrink-0"
                onClick={() => deactivate.mutate(b.id)}>
                <Trash2 size={16} />
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
