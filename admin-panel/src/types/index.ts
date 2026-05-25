export interface User {
  id: number;
  phone: string;
  fullName: string;
  role: 'CLIENT' | 'DRIVER' | 'ADMIN';
  rating: number;
  ratingCount: number;
  enabled: boolean;
  blockedUntil: string | null;
  createdAt: string;
}

export interface Ride {
  id: number;
  status: 'SEARCHING' | 'ACCEPTED' | 'ARRIVED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
  pickupAddress: string;
  dropoffAddress: string;
  price: number;
  requestedCarClass: 'ECONOMY' | 'COMFORT' | 'BUSINESS';
  createdAt: string;
  driverName?: string;
  clientName?: string;
}

export interface Transaction {
  id: number;
  type: 'RIDE_PAYMENT' | 'PAYOUT' | 'REFUND' | 'ADJUSTMENT' | 'COMMISSION' | 'BONUS' | 'PENALTY';
  userId: number;
  userPhone: string;
  userName: string;
  rideId?: number;
  amount: number;
  status: 'PENDING' | 'COMPLETED' | 'FAILED' | 'CANCELLED' | 'REFUNDED';
  description: string;
  createdAt: string;
}

export interface PromoCode {
  id: number;
  code: string;
  type: 'PERCENTAGE' | 'FIXED_AMOUNT' | 'FREE_RIDE';
  discountValue: number;
  usageLimit?: number;
  usageCount: number;
  validFrom: string;
  validUntil: string;
  active: boolean;
}

export interface Review {
  id: number;
  rideId: number;
  reviewerName: string;
  revieweeName: string;
  rating: number;
  comment: string;
  isVisible: boolean;
  isFlagged: boolean;
  createdAt: string;
}

export interface SupportTicket {
  id: number;
  userId: number;
  userName: string;
  subject: string;
  category: 'PAYMENT_ISSUE' | 'RIDE_PROBLEM' | 'DRIVER_COMPLAINT' | 'PASSENGER_COMPLAINT' | 'TECHNICAL_ISSUE' | 'ACCOUNT_ISSUE' | 'PROMO_CODE_ISSUE' | 'REFUND_REQUEST' | 'OTHER';
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';
  status: 'OPEN' | 'IN_PROGRESS' | 'WAITING_FOR_USER' | 'RESOLVED' | 'CLOSED';
  assignedToName?: string;
  createdAt: string;
}

export interface DriverApplication {
  id: number;
  fullName: string;
  phone: string;
  email: string;
  status: 'PENDING' | 'UNDER_REVIEW' | 'APPROVED' | 'REJECTED';
  carClass: 'ECONOMY' | 'COMFORT' | 'BUSINESS';
  submittedAt: string;
}

export interface DashboardMetrics {
  activeRides: number;
  searchingRides: number;
  onlineDrivers: number;
  totalUsers: number;
  totalDrivers: number;
  totalClients: number;
  openTickets?: number;
  inProgressTickets?: number;
}

export interface AuditLog {
  id: number;
  adminId: number;
  adminName: string;
  adminPhone: string;
  action: string;
  target: string;
  details: string;
  createdAt: string;
}

export interface HeatmapCell {
  cellId: string;
  lat: number;
  lon: number;
  weight: number;
}
