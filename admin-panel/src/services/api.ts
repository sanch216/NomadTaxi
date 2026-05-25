import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const authService = {
  login: async (phone: string, password: string) => {
    const response = await api.post('/auth/login', { phone, password });
    if (response.data.token) {
      localStorage.setItem('token', response.data.token);
    }
    return response.data;
  },
  logout: () => {
    localStorage.removeItem('token');
  },
};

export const dashboardService = {
  getMetrics: () => api.get('/admin/dashboard/metrics'),
};

export const userService = {
  getUsers: (params?: any) => api.get('/admin/users', { params }),
  getUser: (id: number) => api.get(`/admin/users/${id}`),
  banUser: (id: number, reason: string, durationHours?: number) => 
    api.post(`/admin/users/${id}/ban`, null, { params: { reason, durationHours } }),
  unbanUser: (id: number) => api.post(`/admin/users/${id}/unban`),
};

export const rideService = {
  getRides: (params?: any) => api.get('/admin/rides', { params }),
  getRide: (id: number) => api.get(`/admin/rides/${id}`),
  cancelRide: (id: number, reason: string) => api.post(`/admin/rides/${id}/cancel`, null, { params: { reason } }),
};

export const transactionService = {
  getTransactions: (params?: any) => api.get('/admin/transactions', { params }),
  getTransaction: (id: number) => api.get(`/admin/transactions/${id}`),
  getUserTransactions: (userId: number) => api.get(`/admin/transactions/user/${userId}`),
  createRefund: (data: any) => api.post('/admin/transactions/refund', data),
  createAdjustment: (data: { userId: number, amount: number, reason: string }) => 
    api.post('/admin/transactions/adjustment', data),
};

export const promoCodeService = {
  getPromoCodes: () => api.get('/admin/promo-codes'),
  getPromoCode: (id: number) => api.get(`/admin/promo-codes/${id}`),
  createPromoCode: (data: any) => api.post('/admin/promo-codes', data),
  updatePromoCode: (id: number, data: any) => api.put(`/admin/promo-codes/${id}`, data),
  deletePromoCode: (id: number) => api.delete(`/admin/promo-codes/${id}`),
  deactivatePromoCode: (id: number) => api.post(`/admin/promo-codes/${id}/deactivate`),
};

export const reviewService = {
  getReviews: (params?: any) => api.get('/admin/reviews', { params }),
  getReview: (id: number) => api.get(`/admin/reviews/${id}`),
  hideReview: (id: number, reason: string) => api.post(`/admin/reviews/${id}/hide`, null, { params: { reason } }),
  showReview: (id: number) => api.post(`/admin/reviews/${id}/show`),
  deleteReview: (id: number) => api.delete(`/admin/reviews/${id}`),
};

export const ticketService = {
  getTickets: (params?: any) => api.get('/admin/tickets', { params }),
  getTicket: (id: number) => api.get(`/admin/tickets/${id}`),
  getTicketMessages: (id: number) => api.get(`/admin/tickets/${id}/messages`),
  addMessage: (id: number, data: any) => api.post(`/admin/tickets/${id}/messages`, data),
  assignTicket: (id: number, assigneeId: number) => api.post(`/admin/tickets/${id}/assign`, null, { params: { assigneeId } }),
  updateStatus: (id: number, status: string) => api.post(`/admin/tickets/${id}/status`, null, { params: { status } }),
  updatePriority: (id: number, priority: string) => api.post(`/admin/tickets/${id}/priority`, null, { params: { priority } }),
  resolveTicket: (id: number, resolutionNotes: string) => api.post(`/admin/tickets/${id}/resolve`, null, { params: { resolutionNotes } }),
  closeTicket: (id: number) => api.post(`/admin/tickets/${id}/close`),
};

export const driverApplicationService = {
  getApplications: (params?: any) => api.get('/admin/driver-applications', { params }),
  getApplication: (id: number) => api.get(`/admin/driver-applications/${id}`),
  approveApplication: (id: number) => api.post(`/admin/driver-applications/${id}/approve`),
  rejectApplication: (id: number, reason: string) => api.post(`/admin/driver-applications/${id}/reject`, null, { params: { reason } }),
  activateDriver: (id: number) => api.post(`/admin/driver-applications/${id}/activate`),
};

export const auditLogsService = {
  getLogs: (params?: any) => api.get('/admin/audit-logs', { params }),
};

export const heatmapService = {
  getLiveHeatmap: () => api.get('/heatmap/live'), // note: it's /api/heatmap/live according to HeatmapController.java
};

export default api;
