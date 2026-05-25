import { useEffect, useState } from 'react';
import { driverApplicationService } from '../services/api';
import { DriverApplication } from '../types';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useToast } from '../components/Toast';
import { useConfirm } from '../components/ConfirmDialog';
import '../pages/Users.css';

function DriverApplications() {
  const [applications, setApplications] = useState<DriverApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'ALL' | 'PENDING' | 'APPROVED' | 'REJECTED'>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;

  const toast = useToast();
  const confirm = useConfirm();

  useEffect(() => {
    loadApplications();
  }, [filter, currentPage]);

  const loadApplications = async () => {
    setLoading(true);
    try {
      const params: any = { 
        page: currentPage, 
        size: pageSize 
      };
      if (filter !== 'ALL') params.status = filter;
      
      const response = await driverApplicationService.getApplications(params);
      
      if (response.data.content) {
        setApplications(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        const data = Array.isArray(response.data) ? response.data : [];
        setApplications(data);
        setTotalPages(1);
        setTotalElements(data.length);
      }
    } catch (error) {
      console.error('Failed to load applications:', error);
      toast.error('Failed to load applications');
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (id: number) => {
    const { confirmed } = await confirm({
      title: 'Approve Application',
      message: `Approve driver application #${id}?`,
      confirmText: 'Approve',
      variant: 'success',
    });
    if (!confirmed) return;

    try {
      await driverApplicationService.approveApplication(id);
      loadApplications();
      toast.success('Application approved');
    } catch (error) {
      toast.error('Failed to approve application');
    }
  };

  const handleReject = async (id: number) => {
    const { confirmed, inputValue } = await confirm({
      title: 'Reject Application',
      message: `Reject driver application #${id}?`,
      confirmText: 'Reject',
      variant: 'danger',
      inputLabel: 'Rejection Reason',
      inputPlaceholder: 'Enter the reason for rejection...',
      inputRequired: true,
    });
    if (!confirmed || !inputValue) return;

    try {
      await driverApplicationService.rejectApplication(id, inputValue);
      loadApplications();
      toast.success('Application rejected');
    } catch (error) {
      toast.error('Failed to reject application');
    }
  };

  const handleActivate = async (id: number) => {
    const { confirmed } = await confirm({
      title: 'Activate Driver',
      message: 'Activate this driver? This will create their account and allow them to accept rides.',
      confirmText: 'Activate',
      variant: 'success',
    });
    if (!confirmed) return;

    try {
      await driverApplicationService.activateDriver(id);
      loadApplications();
      toast.success('Driver activated successfully');
    } catch (error) {
      toast.error('Failed to activate driver');
    }
  };

  const filteredApps = applications.filter(app => 
    app.phone.includes(searchQuery) || 
    (app.fullName && app.fullName.toLowerCase().includes(searchQuery.toLowerCase())) ||
    (app.email && app.email.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  const renderSkeleton = () => (
    <>
      {[...Array(5)].map((_, i) => (
        <tr key={i}>
          {[...Array(8)].map((_, j) => (
            <td key={j}><div className="skeleton-cell" style={{ width: `${40 + Math.random() * 50}%`, height: '1rem' }} /></td>
          ))}
        </tr>
      ))}
    </>
  );

  return (
    <div className="users-page">
      <div className="page-header">
        <h1>Driver Applications</h1>
      </div>

      <div className="table-header-controls">
        <div className="search-bar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input 
            type="text" 
            placeholder="Search by name, phone or email..." 
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div className="filter-buttons">
          <button className={filter === 'ALL' ? 'active' : ''} onClick={() => setFilter('ALL')}>All</button>
          <button className={filter === 'PENDING' ? 'active' : ''} onClick={() => setFilter('PENDING')}>Pending</button>
          <button className={filter === 'APPROVED' ? 'active' : ''} onClick={() => setFilter('APPROVED')}>Approved</button>
          <button className={filter === 'REJECTED' ? 'active' : ''} onClick={() => setFilter('REJECTED')}>Rejected</button>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Full Name</th>
              <th>Phone</th>
              <th>Email</th>
              <th>Car Class</th>
              <th>Status</th>
              <th>Submitted</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : filteredApps.length === 0 ? (
              <tr>
                <td colSpan={8}>
                  <EmptyState icon="applications" title="No applications found" description="No driver applications match the current filter" />
                </td>
              </tr>
            ) : (
              filteredApps.map((app) => (
                <tr key={app.id}>
                  <td>#{app.id}</td>
                  <td><strong>{app.fullName}</strong></td>
                  <td>{app.phone}</td>
                  <td>{app.email}</td>
                  <td>{app.carClass}</td>
                  <td>
                    <span className={`badge badge-${app.status.toLowerCase()}`}>
                      {app.status}
                    </span>
                  </td>
                  <td>{new Date(app.submittedAt).toLocaleString()}</td>
                  <td>
                    {app.status === 'PENDING' && (
                      <>
                        <button
                          className="btn btn-success btn-sm"
                          onClick={() => handleApprove(app.id)}
                          style={{ marginRight: '5px' }}
                        >
                          Approve
                        </button>
                        <button
                          className="btn btn-danger btn-sm"
                          onClick={() => handleReject(app.id)}
                        >
                          Reject
                        </button>
                      </>
                    )}
                    {app.status === 'APPROVED' && (
                      <button
                        className="btn btn-primary btn-sm"
                        onClick={() => handleActivate(app.id)}
                      >
                        Activate Driver
                      </button>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <Pagination 
        currentPage={currentPage}
        totalPages={totalPages}
        totalElements={totalElements}
        pageSize={pageSize}
        onPageChange={setCurrentPage}
      />
    </div>
  );
}

export default DriverApplications;
