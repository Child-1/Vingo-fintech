import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate } from '../lib/utils';
import { Gavel, CheckCircle, XCircle, Clock, AlertCircle, ChevronDown } from 'lucide-react';

interface Dispute {
  id: number;
  transactionId: number;
  reason: string;
  description: string;
  status: 'OPEN' | 'REVIEWING' | 'RESOLVED' | 'REJECTED';
  adminNote: string | null;
  createdAt: string;
  resolvedAt: string | null;
}

interface DisputesResponse { disputes: Dispute[] }

const STATUS_META: Record<string, { label: string; color: string; icon: React.ReactNode }> = {
  OPEN:      { label: 'Open',      color: 'bg-gray-100 text-gray-700',   icon: <AlertCircle size={14} /> },
  REVIEWING: { label: 'Reviewing', color: 'bg-yellow-100 text-yellow-700', icon: <Clock size={14} /> },
  RESOLVED:  { label: 'Resolved',  color: 'bg-green-100 text-green-700',  icon: <CheckCircle size={14} /> },
  REJECTED:  { label: 'Rejected',  color: 'bg-red-100 text-red-700',      icon: <XCircle size={14} /> },
};

export default function DisputesPage() {
  const qc = useQueryClient();
  const [filter, setFilter] = useState('ALL');
  const [selected, setSelected] = useState<Dispute | null>(null);
  const [note, setNote] = useState('');
  const [newStatus, setNewStatus] = useState('');

  const { data, isLoading } = useQuery<DisputesResponse>({
    queryKey: ['disputes'],
    queryFn: () => api.get('/api/admin/disputes').then(r => r.data),
    refetchInterval: 30_000,
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, status, adminNote }: { id: number; status: string; adminNote: string }) =>
      api.put(`/api/admin/disputes/${id}`, { status, adminNote }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['disputes'] });
      setSelected(null);
      setNote('');
      setNewStatus('');
    },
  });

  const disputes = data?.disputes ?? [];
  const filtered = filter === 'ALL' ? disputes : disputes.filter(d => d.status === filter);

  const counts = {
    ALL:      disputes.length,
    OPEN:     disputes.filter(d => d.status === 'OPEN').length,
    REVIEWING:disputes.filter(d => d.status === 'REVIEWING').length,
    RESOLVED: disputes.filter(d => d.status === 'RESOLVED').length,
    REJECTED: disputes.filter(d => d.status === 'REJECTED').length,
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Gavel className="text-red-500" size={24} />
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Disputes</h1>
      </div>

      {/* Filter tabs */}
      <div className="flex flex-wrap gap-2">
        {(['ALL', 'OPEN', 'REVIEWING', 'RESOLVED', 'REJECTED'] as const).map(s => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
              filter === s
                ? 'bg-red-500 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300'
            }`}
          >
            {s === 'ALL' ? 'All' : STATUS_META[s]?.label ?? s}
            <span className="ml-1.5 opacity-70">({counts[s as keyof typeof counts] ?? 0})</span>
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="flex justify-center py-16">
          <div className="w-8 h-8 border-4 border-red-500 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 text-gray-400">No disputes found.</div>
      ) : (
        <div className="space-y-3">
          {filtered.map(d => {
            const meta = STATUS_META[d.status];
            return (
              <div
                key={d.id}
                className="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 p-5 cursor-pointer hover:shadow-md transition-shadow"
                onClick={() => { setSelected(d); setNote(d.adminNote ?? ''); setNewStatus(d.status); }}
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-semibold text-gray-900 dark:text-white text-sm">
                        #{d.id} · {d.reason.replace(/_/g, ' ')}
                      </span>
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${meta.color}`}>
                        {meta.icon} {meta.label}
                      </span>
                    </div>
                    <p className="text-sm text-gray-600 dark:text-gray-300 line-clamp-2">{d.description}</p>
                    {d.adminNote && (
                      <p className="mt-1 text-xs text-yellow-600 italic">Note: {d.adminNote}</p>
                    )}
                  </div>
                  <div className="text-right shrink-0">
                    <p className="text-xs text-gray-400">Tx #{d.transactionId}</p>
                    <p className="text-xs text-gray-400">{formatDate(d.createdAt)}</p>
                    <ChevronDown size={16} className="text-gray-400 mt-1 ml-auto" />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Review modal */}
      {selected && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 rounded-2xl w-full max-w-lg shadow-2xl">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">
                Dispute #{selected.id} — {selected.reason.replace(/_/g, ' ')}
              </h2>
              <p className="text-xs text-gray-400 mt-1">Transaction #{selected.transactionId} · Filed {formatDate(selected.createdAt)}</p>
            </div>

            <div className="p-6 space-y-4">
              <div>
                <p className="text-xs font-semibold text-gray-500 uppercase mb-1">User Description</p>
                <p className="text-sm text-gray-700 dark:text-gray-300 bg-gray-50 dark:bg-gray-700 p-3 rounded-lg">{selected.description}</p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Update Status</label>
                <select
                  value={newStatus}
                  onChange={e => setNewStatus(e.target.value)}
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                >
                  <option value="OPEN">Open</option>
                  <option value="REVIEWING">Reviewing</option>
                  <option value="RESOLVED">Resolved</option>
                  <option value="REJECTED">Rejected</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Admin Note</label>
                <textarea
                  value={note}
                  onChange={e => setNote(e.target.value)}
                  rows={3}
                  placeholder="Add a note visible to the user…"
                  className="w-full border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white resize-none"
                />
              </div>
            </div>

            <div className="p-6 border-t border-gray-200 dark:border-gray-700 flex justify-end gap-3">
              <button
                onClick={() => { setSelected(null); setNote(''); setNewStatus(''); }}
                className="px-4 py-2 rounded-lg text-sm border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                disabled={updateMutation.isPending}
                onClick={() => updateMutation.mutate({ id: selected.id, status: newStatus, adminNote: note })}
                className="px-5 py-2 rounded-lg text-sm bg-red-500 text-white font-semibold hover:bg-red-600 disabled:opacity-50"
              >
                {updateMutation.isPending ? 'Saving…' : 'Save Changes'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
