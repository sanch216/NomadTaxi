import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { lazy, Suspense } from 'react';
import Layout from './components/Layout';
import ErrorBoundary from './components/ErrorBoundary';
import { ToastProvider } from './components/Toast';
import { ConfirmProvider } from './components/ConfirmDialog';

// Lazy loading heavy components
const Login = lazy(() => import('./pages/Login'));
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Users = lazy(() => import('./pages/Users'));
const Rides = lazy(() => import('./pages/Rides'));
const Transactions = lazy(() => import('./pages/Transactions'));
const PromoCodes = lazy(() => import('./pages/PromoCodes'));
const Reviews = lazy(() => import('./pages/Reviews'));
const Tickets = lazy(() => import('./pages/Tickets'));
const DriverApplications = lazy(() => import('./pages/DriverApplications'));
const AuditLogs = lazy(() => import('./pages/AuditLogs'));
const LiveMap = lazy(() => import('./pages/LiveMap'));

function App() {
  const isAuthenticated = !!localStorage.getItem('token');

  return (
    <ToastProvider>
      <ConfirmProvider>
        <BrowserRouter>
          <Suspense fallback={<div style={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary-accent)' }}>Loading Panel...</div>}>
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route
                path="/"
                element={
                  isAuthenticated ? (
                    <Layout />
                  ) : (
                    <Navigate to="/login" replace />
                  )
                }
              >
                <Route index element={<ErrorBoundary><Dashboard /></ErrorBoundary>} />
                <Route path="users" element={<ErrorBoundary><Users /></ErrorBoundary>} />
                <Route path="rides" element={<ErrorBoundary><Rides /></ErrorBoundary>} />
                <Route path="transactions" element={<ErrorBoundary><Transactions /></ErrorBoundary>} />
                <Route path="promo-codes" element={<ErrorBoundary><PromoCodes /></ErrorBoundary>} />
                <Route path="reviews" element={<ErrorBoundary><Reviews /></ErrorBoundary>} />
                <Route path="tickets" element={<ErrorBoundary><Tickets /></ErrorBoundary>} />
                <Route path="driver-applications" element={<ErrorBoundary><DriverApplications /></ErrorBoundary>} />
                <Route path="audit-logs" element={<ErrorBoundary><AuditLogs /></ErrorBoundary>} />
                <Route path="live-map" element={<ErrorBoundary><LiveMap /></ErrorBoundary>} />
              </Route>
            </Routes>
          </Suspense>
        </BrowserRouter>
      </ConfirmProvider>
    </ToastProvider>
  );
}

export default App;
