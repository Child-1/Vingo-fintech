import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNaira(amount: number | string): string {
  const n = typeof amount === 'string' ? parseFloat(amount) : amount;
  return new Intl.NumberFormat('en-NG', {
    style: 'currency',
    currency: 'NGN',
    minimumFractionDigits: 2,
  }).format(n);
}

export function formatNumber(n: number): string {
  return new Intl.NumberFormat('en-NG').format(n);
}

export function formatDate(d: string | Date): string {
  return new Intl.DateTimeFormat('en-NG', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  }).format(new Date(d));
}

export function formatDateShort(d: string | Date): string {
  return new Intl.DateTimeFormat('en-NG', {
    day: '2-digit', month: 'short', year: 'numeric',
  }).format(new Date(d));
}

export function txStatusBadge(status: string) {
  if (status === 'SUCCESS') return 'badge-green';
  if (status === 'FAILED')  return 'badge-red';
  if (status === 'PENDING') return 'badge-yellow';
  return 'badge-gray';
}

export function kycBadge(status: string) {
  if (status === 'APPROVED') return 'badge-green';
  if (status === 'PENDING')  return 'badge-yellow';
  if (status === 'REJECTED') return 'badge-red';
  return 'badge-gray';
}

export function roleBadge(role: string) {
  if (role === 'SUPER_ADMIN') return 'badge-purple';
  if (role === 'ADMIN')       return 'badge-blue';
  if (role === 'STAFF')       return 'badge-yellow';
  return 'badge-gray';
}

export function accountStatusBadge(status: string) {
  if (status === 'ACTIVE')    return 'badge-green';
  if (status === 'SUSPENDED') return 'badge-yellow';
  if (status === 'FROZEN')    return 'badge-red';
  return 'badge-gray';
}
