import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate } from '../lib/utils';
import { AtSign, Check, X } from 'lucide-react';

export default function MyrabaTagsPage() {
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['vingtag-requests'],
    queryFn: () => api.get('/api/admin/tag-requests/pending').then(r => r.data),
  });

  const resolve = useMutation({
    mutationFn: ({ id, action }: { id: number; action: 'approve' | 'deny' }) =>
      api.put(`/api/admin/tag-requests/${id}/decision`, { approved: action === 'approve' }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['vingtag-requests'] }),
  });

  const pending = Array.isArray(data) ? data : (data?.content ?? []);

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold text-white">MyrabaTag Requests</h1>
        <p className="text-myraba-hint text-sm">{pending.length} pending</p>
      </div>

      {isLoading && <p className="text-myraba-hint">Loading…</p>}

      {!isLoading && pending.length === 0 && (
        <div className="card flex flex-col items-center py-12 text-center">
          <AtSign size={40} className="text-myraba-success mb-3" />
          <p className="text-myraba-second font-medium">All caught up!</p>
          <p className="text-myraba-hint text-sm mt-1">No pending MyrabaTag change requests.</p>
        </div>
      )}

      {pending.length > 0 && (
        <div className="space-y-3">
          <h2 className="text-myraba-second text-xs uppercase tracking-wider">Pending Requests</h2>
          {pending.map((r: any) => (
            <div key={r.id} className="card flex items-center justify-between gap-4">
              <div className="flex-1">
                <div className="flex items-center gap-2 text-sm">
                  <span className="text-myraba-second font-medium">@{r.currentTag}</span>
                  <span className="text-myraba-hint">→</span>
                  <span className="text-brand font-semibold">@{r.requestedTag}</span>
                </div>
                <p className="text-myraba-hint text-xs mt-0.5">{r.fullName} · {formatDate(r.createdAt)}</p>
                {r.reason && <p className="text-myraba-second text-xs mt-1 italic">"{r.reason}"</p>}
              </div>
              <div className="flex gap-2 flex-shrink-0">
                <button
                  className="btn-primary flex items-center gap-1.5 text-xs py-1.5 px-3"
                  disabled={resolve.isPending}
                  onClick={() => resolve.mutate({ id: r.id, action: 'approve' })}>
                  <Check size={13} /> Approve
                </button>
                <button
                  className="btn-danger flex items-center gap-1.5 text-xs py-1.5 px-3"
                  disabled={resolve.isPending}
                  onClick={() => resolve.mutate({ id: r.id, action: 'deny' })}>
                  <X size={13} /> Deny
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

    </div>
  );
}
