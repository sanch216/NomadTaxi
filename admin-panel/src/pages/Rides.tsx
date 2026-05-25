import { useEffect, useState } from 'react';
import { rideService } from '../services/api';
import { Ride } from '../types';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useDebounce } from '../hooks/useDebounce';
import { useToast } from '../components/Toast';
import { useConfirm } from '../components/ConfirmDialog';
import '../pages/Users.css';

function Rides() {
  const [rides, setRides] = useState<Ride[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const debouncedSearchQuery = useDebounce(searchQuery, 300);
  const [filter, setFilter] = useState<'ALL' | 'SEARCHING' | 'ACCEPTED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED'>('ALL');

  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;

  const toast = useToast();
  const confirm = useConfirm();

  useEffect(() => {
    setCurrentPage(0);
  }, [filter]);

  useEffect(() => {
    loadRides();
  }, [filter, currentPage]);

  const loadRides = async () => {
    setLoading(true);
    try {
      const params: any = { page: currentPage, size: pageSize };
      if (filter !== 'ALL') params.status = filter;
      const response = await rideService.getRides(params);

      if (response.data.content) {
        setRides(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        setRides(Array.isArray(response.data) ? response.data : []);
        setTotalPages(1);
        setTotalElements(Array.isArray(response.data) ? response.data.length : 0);
      }
    } catch (error) {
      console.error('Failed to load rides:', error);
      toast.error('Failed to load rides');
    } finally {
      setLoading(false);
    }
  };

  const handleCancelRide = async (id: number) => {
    const { confirmed, inputValue } = await confirm({
      title: 'Cancel Ride',
      message: `Are you sure you want to force-cancel ride #${id}?`,
      confirmText: 'Cancel Ride',
      variant: 'danger',
      inputLabel: 'Cancellation Reason',
      inputPlaceholder: 'e.g. Driver stuck, passenger complaint...',
      inputRequired: true,
    });
    if (!confirmed || !inputValue) return;

    try {
      await rideService.cancelRide(id, inputValue);
      loadRides();
      toast.success('Ride cancelled successfully');
    } catch (error) {
      toast.error('Failed to cancel ride');
    }
  };

  const filteredRides = rides.filter(r => 
    r.clientName?.toLowerCase().includes(debouncedSearchQuery.toLowerCase()) || 
    r.driverName?.toLowerCase().includes(debouncedSearchQuery.toLowerCase()) ||
    r.id.toString().includes(debouncedSearchQuery)
  );

  const renderSkeleton = () => (
    <>
      {[...Array(8)].map((_, i) => (
        <tr key={i}>
          {[...Array(7)].map((_, j) => (
            <td key={j}>
              <div className="skeleton-cell" style={{ width: `${50 + Math.random() * 50}%`, height: '1rem' }} />
            </td>
          ))}
        </tr>
      ))}
    </>
  );

  return (
    <div className="users-page">
      <div className="page-header" style={{ marginBottom: '1rem' }}>
        <h1>Rides Management</h1>
      </div>

      <div className="table-header-controls">
        <div className="search-bar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input 
            type="text" 
            placeholder="Search by ID, Client or Driver name..." 
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div className="filter-buttons" style={{ overflowX: 'auto', display: 'flex', whiteSpace: 'nowrap' }}>
          <button className={filter === 'ALL' ? 'active' : ''} onClick={() => setFilter('ALL')}>All</button>
          <button className={filter === 'SEARCHING' ? 'active' : ''} onClick={() => setFilter('SEARCHING')}>Searching</button>
          <button className={filter === 'ACCEPTED' ? 'active' : ''} onClick={() => setFilter('ACCEPTED')}>Accepted</button>
          <button className={filter === 'IN_PROGRESS' ? 'active' : ''} onClick={() => setFilter('IN_PROGRESS')}>In Progress</button>
          <button className={filter === 'COMPLETED' ? 'active' : ''} onClick={() => setFilter('COMPLETED')}>Completed</button>
          <button className={filter === 'CANCELLED' ? 'active' : ''} onClick={() => setFilter('CANCELLED')}>Cancelled</button>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Client</th>
              <th>Driver</th>
              <th>Fare</th>
              <th>Status</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : filteredRides.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <EmptyState
                    icon="rides"
                    title="No rides found"
                    description={searchQuery ? 'Try adjusting your search query' : 'No rides match the selected filter'}
                  />
                </td>
              </tr>
            ) : (
              filteredRides.map((ride) => (
                <tr key={ride.id}>
                  <td>#{ride.id}</td>
                  <td>
                    <strong>{ride.clientName || 'Unknown'}</strong>
                  </td>
                  <td>
                    {ride.driverName ? (
                      <strong>{ride.driverName}</strong>
                    ) : (
                      <span style={{color: 'var(--text-muted)'}}>Searching...</span>
                    )}
                  </td>
                  <td>
                    ${ride.price ? ride.price.toFixed(2) : '-'}
                  </td>
                  <td>
                    <span className={`badge badge-${ride.status.toLowerCase()}`}>
                      {ride.status}
                    </span>
                  </td>
                  <td>{new Date(ride.createdAt).toLocaleString()}</td>
                  <td>
                    {(ride.status === 'SEARCHING' || ride.status === 'ACCEPTED' || ride.status === 'IN_PROGRESS') && (
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={() => handleCancelRide(ride.id)}
                      >
                        Force Cancel
                      </button>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        {!loading && (
          <Pagination
            currentPage={currentPage}
            totalPages={totalPages}
            totalElements={totalElements}
            pageSize={pageSize}
            onPageChange={setCurrentPage}
          />
        )}
      </div>
    </div>
  );
}

export default Rides;
