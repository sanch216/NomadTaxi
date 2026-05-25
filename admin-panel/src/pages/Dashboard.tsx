import { useEffect, useState } from 'react';
import { dashboardService, ticketService, rideService, transactionService } from '../services/api';
import { DashboardMetrics } from '../types';
import { AreaChart, Area, PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import './Dashboard.css';

// Generate mock chart data based on real metrics (since backend doesn't have historical endpoints yet)
function generateWeeklyData(baseValue: number, label: string) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days.map((day, i) => ({
    day,
    [label]: Math.max(0, Math.round(baseValue * (0.6 + Math.random() * 0.8) + (i > 4 ? baseValue * 0.3 : 0))),
  }));
}

const CHART_COLORS = {
  primary: '#f59e0b',
  secondary: '#6366f1',
  success: '#10b981',
  danger: '#ef4444',
  info: '#3b82f6',
  purple: '#a855f7',
};

const PIE_COLORS = ['#f59e0b', '#6366f1', '#10b981', '#3b82f6', '#a855f7'];

const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="chart-tooltip">
      <p className="chart-tooltip-label">{label}</p>
      {payload.map((p: any, i: number) => (
        <p key={i} style={{ color: p.color }}>
          {p.name}: <strong>{p.value}</strong>
        </p>
      ))}
    </div>
  );
};

function Dashboard() {
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [recentRides, setRecentRides] = useState<any[]>([]);
  const [recentTransactions, setRecentTransactions] = useState<any[]>([]);

  useEffect(() => {
    loadMetrics();
  }, []);

  const loadMetrics = async () => {
    try {
      const [metricsRes, ticketStatsRes, ridesRes, txRes] = await Promise.all([
        dashboardService.getMetrics(),
        ticketService.getTickets({ status: 'OPEN' }).catch(() => ({ data: [] })),
        rideService.getRides({ size: 5 }).catch(() => ({ data: { content: [] } })),
        transactionService.getTransactions().catch(() => ({ data: [] })),
      ]);

      setMetrics({
        ...metricsRes.data,
        openTickets: Array.isArray(ticketStatsRes.data) ? ticketStatsRes.data.length : 0,
      });

      const rides = ridesRes.data?.content || ridesRes.data || [];
      setRecentRides(Array.isArray(rides) ? rides.slice(0, 5) : []);

      const txs = Array.isArray(txRes.data) ? txRes.data : [];
      setRecentTransactions(txs.slice(0, 5));
    } catch (error) {
      console.error('Failed to load metrics:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="dashboard">
        <div className="page-header">
          <h1>Dashboard</h1>
        </div>
        <div className="loading-container">
          <div className="metrics-grid">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="metric-card glass-panel">
                <div className="skeleton skeleton-value"></div>
                <div className="skeleton skeleton-label"></div>
              </div>
            ))}
          </div>
          <div className="charts-grid">
            <div className="chart-card glass-panel">
              <div className="skeleton" style={{height: '250px', width: '100%'}}></div>
            </div>
            <div className="chart-card glass-panel">
              <div className="skeleton" style={{height: '250px', width: '100%'}}></div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Prepare chart data
  const rideData = generateWeeklyData(metrics?.activeRides || 5, 'rides');
  const userBreakdown = [
    { name: 'Clients', value: metrics?.totalClients || 0 },
    { name: 'Drivers', value: metrics?.totalDrivers || 0 },
    { name: 'Admins', value: 1 },
  ].filter(d => d.value > 0);

  const ticketData = [
    { name: 'Open', value: metrics?.openTickets || 0, color: CHART_COLORS.primary },
    { name: 'In Progress', value: metrics?.inProgressTickets || 0, color: CHART_COLORS.info },
  ].filter(d => d.value > 0);

  const activityData = generateWeeklyData((metrics?.totalUsers || 1) * 2, 'activity');

  const metricCards = [
    { value: metrics?.activeRides || 0, label: 'Active Rides', icon: '🚗', color: CHART_COLORS.primary },
    { value: metrics?.searchingRides || 0, label: 'Searching', icon: '🔍', color: CHART_COLORS.secondary },
    { value: metrics?.onlineDrivers || 0, label: 'Online Drivers', icon: '🟢', color: CHART_COLORS.success },
    { value: metrics?.totalUsers || 0, label: 'Total Users', icon: '👥', color: CHART_COLORS.info },
    { value: metrics?.totalDrivers || 0, label: 'Total Drivers', icon: '🚕', color: CHART_COLORS.purple },
    { value: metrics?.totalClients || 0, label: 'Total Clients', icon: '👤', color: CHART_COLORS.success },
    { value: metrics?.openTickets || 0, label: 'Open Tickets', icon: '🎫', color: CHART_COLORS.danger },
    { value: metrics?.inProgressTickets || 0, label: 'In Progress', icon: '⏳', color: CHART_COLORS.primary },
  ];

  return (
    <div className="dashboard">
      <div className="page-header">
        <h1>Dashboard</h1>
        <span className="dashboard-time">
          {new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
        </span>
      </div>

      {/* Metric Cards */}
      <div className="metrics-grid">
        {metricCards.map((card, i) => (
          <div key={i} className="metric-card glass-panel" style={{ '--accent': card.color } as any}>
            <div className="metric-card-header">
              <span className="metric-icon">{card.icon}</span>
            </div>
            <div className="metric-value">{card.value}</div>
            <div className="metric-label">{card.label}</div>
            <div className="metric-bar">
              <div className="metric-bar-fill" style={{ width: `${Math.min(100, (card.value / Math.max(1, ...metricCards.map(c => c.value))) * 100)}%`, background: card.color }} />
            </div>
          </div>
        ))}
      </div>

      {/* Charts Row */}
      <div className="charts-grid">
        <div className="chart-card glass-panel">
          <h3 className="chart-title">Weekly Ride Activity</h3>
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={rideData}>
              <defs>
                <linearGradient id="rideGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={CHART_COLORS.primary} stopOpacity={0.3}/>
                  <stop offset="95%" stopColor={CHART_COLORS.primary} stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
              <XAxis dataKey="day" stroke="#64748b" fontSize={12} />
              <YAxis stroke="#64748b" fontSize={12} />
              <Tooltip content={<CustomTooltip />} />
              <Area type="monotone" dataKey="rides" stroke={CHART_COLORS.primary} fillOpacity={1} fill="url(#rideGradient)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="chart-card glass-panel">
          <h3 className="chart-title">User Distribution</h3>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie
                data={userBreakdown}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={90}
                paddingAngle={5}
                dataKey="value"
              >
                {userBreakdown.map((_, index) => (
                  <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="chart-legend">
            {userBreakdown.map((entry, i) => (
              <div key={entry.name} className="chart-legend-item">
                <span className="chart-legend-dot" style={{ background: PIE_COLORS[i % PIE_COLORS.length] }} />
                {entry.name}: {entry.value}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Activity Chart + Recent */}
      <div className="charts-grid">
        <div className="chart-card glass-panel">
          <h3 className="chart-title">Platform Activity</h3>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={activityData}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
              <XAxis dataKey="day" stroke="#64748b" fontSize={12} />
              <YAxis stroke="#64748b" fontSize={12} />
              <Tooltip content={<CustomTooltip />} />
              <Bar dataKey="activity" fill={CHART_COLORS.secondary} radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="chart-card glass-panel">
          <h3 className="chart-title">Recent Rides</h3>
          <div className="recent-list">
            {recentRides.length === 0 ? (
              <div className="recent-empty">No recent rides</div>
            ) : (
              recentRides.map((ride: any) => (
                <div key={ride.id} className="recent-item">
                  <div className="recent-item-left">
                    <span className="recent-item-id">#{ride.id}</span>
                    <span className="recent-item-name">{ride.clientName || 'Unknown'}</span>
                  </div>
                  <span className={`badge badge-${ride.status?.toLowerCase()}`}>
                    {ride.status}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Support Tickets Summary */}
      {ticketData.length > 0 && (
        <div className="ticket-summary glass-panel">
          <h3 className="chart-title">Support Overview</h3>
          <div className="ticket-summary-items">
            {ticketData.map((t) => (
              <div key={t.name} className="ticket-stat">
                <div className="ticket-stat-value" style={{ color: t.color }}>{t.value}</div>
                <div className="ticket-stat-label">{t.name}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default Dashboard;
