export interface LoginResponse {
  token: string;
  myrabaHandle: string;
  myrabaTag: string;
  role: string;
}

export interface DashboardStats {
  totalUsers: number;
  newUsersToday: number;
  kycPending: number;
  totalVolume: number;
  systemLiquidity: number;
  totalServiceFees: number;
  activeThrifts: number;
  totalLockedInThrifts: number;
  pendingPayouts: number;
  failedTransactions24h: number;
}

export interface AdminUser {
  id: number;
  myrabaHandle: string;
  fullName: string;
  phone?: string;
  email?: string;
  accountNumber: string;
  role: string;
  accountStatus: string;
  kycStatus: string;
  createdAt: string;
}

export interface Transaction {
  id: number;
  type: string;
  amount: string;
  fee?: string;
  description?: string;
  senderHandle?: string;
  receiverHandle?: string;
  status: string;
  createdAt: string;
}

export interface PagedResponse<T> {
  transactions?: T[];
  users?: T[];
  content?: T[];
  total: number;
  page: number;
  size: number;
}

export interface Report {
  from: string;
  to: string;
  totalVolume: string;
  totalFees: string;
  totalTransactions: number;
  successfulTransactions: number;
  successRate: string;
}

export interface AuditLog {
  id: number;
  adminHandle: string;
  action: string;
  targetType: string;
  targetId: string;
  details: string;
  previousValue?: string;
  newValue?: string;
  createdAt: string;
}

export interface BroadcastMessage {
  id: number;
  title: string;
  body: string;
  type: string;
  audience: string;
  active: boolean;
  expiresAt?: string;
  createdAt: string;
}

export interface ThriftCategory {
  id: number;
  name: string;
  contributionAmount: string;
  contributionFrequency: string;
  durationInCycles: number;
  payoutAmount: string;
  isActive: boolean;
  memberCount: number;
}

export interface GiftCategory {
  id: number;
  name: string;
  slug: string;
  emoji: string;
  active: boolean;
}

export interface GiftItem {
  id: number;
  name: string;
  emoji: string;
  nairaValue: string;
  active: boolean;
}

export interface SystemHealth {
  status: string;
  responseTimeMs: number;
  dbConnected: boolean;
}

export interface KycSubmission {
  id: number;
  userId: number;
  userHandle: string;
  fullName: string;
  type: string;
  maskedNumber: string;
  status: string;
  submittedAt: string;
}

export interface MyrabaTagRequest {
  id: number;
  userId: number;
  currentHandle: string;
  requestedHandle: string;
  status: string;
  createdAt: string;
}
