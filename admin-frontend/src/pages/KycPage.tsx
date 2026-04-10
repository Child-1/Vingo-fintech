import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate, kycBadge } from '../lib/utils';
import { ShieldCheck, ShieldX, Clock } from 'lucide-react';

export default function KycPage() {
  const qc = useQueryClient();

  const { data: pending, isLoading } = useQuery({
    queryKey: ['kyc-pending'],
    queryFn: () => api.get('/api/admin/users/kyc/pending').then(r => r.data),
  });

  const updateKyc = useMutation({
    mutationFn: ({ id, status }: { id: number; status: string }) =>
      api.put(`/api/admin/users/${id}/kyc`, { status }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['kyc-pending'] }),
  });

  const users = Array.isArray(pending) ? pending : (pending?.users ?? []);

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold text-white">KYC Review</h1>
        <p className="text-myraba-hint text-sm">{users.length} pending submissions</p>
      </div>

      {isLoading && <p className="text-myraba-hint">Loading…</p>}

      {!isLoading && users.length === 0 && (
        <div className="card flex flex-col items-center py-12 text-center">
          <ShieldCheck size={40} className="text-myraba-success mb-3" />
          <p className="text-myraba-second font-medium">All caught up!</p>
          <p className="text-myraba-hint text-sm mt-1">No pending KYC submissions.</p>
        </div>
      )}

      <div className="space-y-3">
        {users.map((u: any) => (
          <div key={u.id} className="card flex items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 rounded-full bg-brand/20 flex items-center justify-center text-brand font-bold flex-shrink-0">
                {(u.fullName ?? '?')[0]}
              </div>
              <div>
                <p className="text-white font-medium text-sm">{u.fullName}</p>
                <p className="text-myraba-hint text-xs">@{u.myrabaHandle}</p>
                <div className="flex items-center gap-2 mt-1">
                  <span className={kycBadge(u.kycStatus)}>{u.kycStatus}</span>
                  {u.createdAt && <span className="text-myraba-hint text-xs flex items-center gap-1"><Clock size={10} />{formatDate(u.createdAt)}</span>}
                </div>
              </div>
            </div>
            <div className="flex gap-2 flex-shrink-0">
              <button className="btn-primary flex items-center gap-1.5 text-xs py-1.5 px-3"
                onClick={() => updateKyc.mutate({ id: u.id, status: 'APPROVED' })}>
                <ShieldCheck size={13} /> Approve
              </button>
              <button className="btn-danger flex items-center gap-1.5 text-xs py-1.5 px-3"
                onClick={() => updateKyc.mutate({ id: u.id, status: 'REJECTED' })}>
                <ShieldX size={13} /> Reject
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
