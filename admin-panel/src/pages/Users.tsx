import { useEffect, useState } from 'react';
import { userService, transactionService } from '../services/api';
import { User, Transaction } from '../types';
import SlideOutPanel from '../components/SlideOutPanel';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useDebounce } from '../hooks/useDebounce';
import { useToast } from '../components/Toast';
import { useConfirm } from '../components/ConfirmDialog';
import './Users.css';

function Users() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'ALL' | 'CLIENT' | 'DRIVER' | 'ADMIN'>('ALL');
  
  type SortColumn = 'id' | 'phone' | 'fullName' | 'role' | 'rating' | 'status';
  const [sortConfig, setSortConfig] = useState<{ key: SortColumn; direction: 'asc' | 'desc' } | null>(null);
  
  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;

  const [searchQuery, setSearchQuery] = useState('');
  const debouncedSearchQuery = useDebounce(searchQuery, 300);

  // Details Panel State
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [userTransactions, setUserTransactions] = useState<Transaction[]>([]);
  const [loadingDetails, setLoadingDetails] = useState(false);

  const toast = useToast();
  const confirm = useConfirm();

  useEffect(() => {
    setCurrentPage(0);
  }, [filter]);

  useEffect(() => {
    loadUsers();
  }, [filter, currentPage]);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const params: any = { page: currentPage, size: pageSize };
      if (filter !== 'ALL') params.role = filter;
      const response = await userService.getUsers(params);
      
      if (response.data.content) {
        setUsers(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        setUsers(Array.isArray(response.data) ? response.data : []);
        setTotalPages(1);
        setTotalElements(Array.isArray(response.data) ? response.data.length : 0);
      }
    } catch (error) {
      console.error('Failed to load users:', error);
      toast.error('Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const handleRowClick = async (user: User) => {
    setSelectedUser(user);
    setLoadingDetails(true);
    setUserTransactions([]);
    try {
      const response = await transactionService.getUserTransactions(user.id);
      const data = response.data.content !== undefined ? response.data.content : response.data;
      setUserTransactions(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Failed to load user transactions:', error);
    } finally {
      setLoadingDetails(false);
    }
  };

  const handleBanUser = async (userId: number, e: React.MouseEvent) => {
    e.stopPropagation();
    const { confirmed, inputValue } = await confirm({
      title: 'Ban User',
      message: `Are you sure you want to ban user #${userId}?`,
      confirmText: 'Ban User',
      variant: 'danger',
      inputLabel: 'Ban Reason',
      inputPlaceholder: 'Enter the reason for banning this user...',
      inputRequired: true,
    });
    if (!confirmed || !inputValue) return;

    try {
      await userService.banUser(userId, inputValue);
      loadUsers();
      toast.success('User banned successfully');
    } catch (error) {
      toast.error('Failed to ban user');
    }
  };

  const handleUnbanUser = async (userId: number, e: React.MouseEvent) => {
    e.stopPropagation();
    const { confirmed } = await confirm({
      title: 'Unban User',
      message: `Are you sure you want to unban user #${userId}?`,
      confirmText: 'Unban',
      variant: 'success',
    });
    if (!confirmed) return;

    try {
      await userService.unbanUser(userId);
      loadUsers();
      toast.success('User unbanned successfully');
    } catch (error) {
      toast.error('Failed to unban user');
    }
  };

  const filteredUsers = users.filter(user => 
    user.phone.includes(debouncedSearchQuery) || 
    (user.fullName && user.fullName.toLowerCase().includes(debouncedSearchQuery.toLowerCase()))
  );

  const sortedUsers = [...filteredUsers].sort((a, b) => {
    if (!sortConfig) return 0;
    
    const { key, direction } = sortConfig;
    let aValue: any = key === 'status' ? (a.enabled ? 1 : 0) : a[key as keyof User];
    let bValue: any = key === 'status' ? (b.enabled ? 1 : 0) : b[key as keyof User];
    
    // Handle nulls
    if (aValue === null) aValue = '';
    if (bValue === null) bValue = '';

    if (aValue < bValue) return direction === 'asc' ? -1 : 1;
    if (aValue > bValue) return direction === 'asc' ? 1 : -1;
    return 0;
  });

  const handleSort = (key: SortColumn) => {
    let direction: 'asc' | 'desc' = 'asc';
    if (sortConfig && sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });
  };

  const getSortIcon = (key: SortColumn) => {
    if (sortConfig?.key !== key) return <span className="sort-icon">↕️</span>;
    return sortConfig.direction === 'asc' ? <span className="sort-icon active">↑</span> : <span className="sort-icon active">↓</span>;
  };

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
      <div className="page-header">
        <h1>Users Management</h1>
      </div>

      <div className="table-header-controls">
        <div className="search-bar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input 
            type="text" 
            placeholder="Search by phone or name..." 
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div className="filter-buttons">
          <button
            className={filter === 'ALL' ? 'active' : ''}
            onClick={() => setFilter('ALL')}
          >
            All
          </button>
          <button
            className={filter === 'CLIENT' ? 'active' : ''}
            onClick={() => setFilter('CLIENT')}
          >
            Clients
          </button>
          <button
            className={filter === 'DRIVER' ? 'active' : ''}
            onClick={() => setFilter('DRIVER')}
          >
            Drivers
          </button>
          <button
            className={filter === 'ADMIN' ? 'active' : ''}
            onClick={() => setFilter('ADMIN')}
          >
            Admins
          </button>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table" style={{ cursor: 'pointer' }}>
          <thead>
            <tr>
              <th onClick={() => handleSort('id')} className="sortable">ID {getSortIcon('id')}</th>
              <th onClick={() => handleSort('phone')} className="sortable">Phone {getSortIcon('phone')}</th>
              <th onClick={() => handleSort('fullName')} className="sortable">Full Name {getSortIcon('fullName')}</th>
              <th onClick={() => handleSort('role')} className="sortable">Role {getSortIcon('role')}</th>
              <th onClick={() => handleSort('rating')} className="sortable">Rating {getSortIcon('rating')}</th>
              <th onClick={() => handleSort('status')} className="sortable">Status {getSortIcon('status')}</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : sortedUsers.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <EmptyState
                    icon="users"
                    title="No users found"
                    description={searchQuery ? 'Try adjusting your search query' : 'No users match the selected filter'}
                  />
                </td>
              </tr>
            ) : (
              sortedUsers.map((user) => (
                <tr key={user.id} onClick={() => handleRowClick(user)} className="hoverable-row">
                  <td>#{user.id}</td>
                  <td><strong>{user.phone}</strong></td>
                  <td>{user.fullName || '-'}</td>
                  <td>
                    <span className={`badge badge-${user.role.toLowerCase()}`}>
                      {user.role}
                    </span>
                  </td>
                  <td>
                    {user.rating.toFixed(1)} <span style={{color: 'var(--text-muted)'}}>({user.ratingCount})</span>
                  </td>
                  <td>
                    {user.enabled ? (
                      <span className="badge badge-success">Active</span>
                    ) : (
                      <span className="badge badge-danger">Banned</span>
                    )}
                  </td>
                  <td>
                    {user.enabled ? (
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={(e) => handleBanUser(user.id, e)}
                      >
                        Ban
                      </button>
                    ) : (
                      <button
                        className="btn btn-success btn-sm"
                        onClick={(e) => handleUnbanUser(user.id, e)}
                      >
                        Unban
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

      <SlideOutPanel 
        isOpen={!!selectedUser} 
        onClose={() => setSelectedUser(null)} 
        title="User Details"
      >
        {selectedUser && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            <div className="glass-panel" style={{ padding: '1.5rem', borderRadius: '12px' }}>
              <h3 style={{ margin: '0 0 1rem 0', color: 'var(--primary-accent)' }}>Profile</h3>
              <p><strong>ID:</strong> #{selectedUser.id}</p>
              <p><strong>Name:</strong> {selectedUser.fullName || 'Not provided'}</p>
              <p><strong>Phone:</strong> {selectedUser.phone}</p>
              <p><strong>Role:</strong> <span className={`badge badge-${selectedUser.role.toLowerCase()}`}>{selectedUser.role}</span></p>
              <p><strong>Rating:</strong> ⭐ {selectedUser.rating.toFixed(1)} ({selectedUser.ratingCount} reviews)</p>
              <p><strong>Status:</strong> {selectedUser.enabled ? 'Active' : 'Banned'}</p>
              <p><strong>Registered:</strong> {new Date(selectedUser.createdAt).toLocaleDateString()}</p>
            </div>

            <div className="glass-panel" style={{ padding: '1.5rem', borderRadius: '12px' }}>
              <h3 style={{ margin: '0 0 1rem 0', color: 'var(--secondary-accent)' }}>Recent Transactions</h3>
              {loadingDetails ? (
                <p style={{ color: 'var(--text-muted)' }}>Loading transactions...</p>
              ) : userTransactions.length === 0 ? (
                <p style={{ color: 'var(--text-muted)' }}>No transactions found.</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.8rem' }}>
                  {userTransactions.slice(0, 5).map(tx => (
                    <div key={tx.id} style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '0.5rem' }}>
                      <div>
                        <strong>{tx.type}</strong>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{new Date(tx.createdAt).toLocaleDateString()}</div>
                      </div>
                      <div style={{ color: tx.amount >= 0 ? 'var(--success)' : 'var(--danger)', fontWeight: 'bold' }}>
                        {tx.amount >= 0 ? '+' : ''}{tx.amount.toFixed(2)}
                      </div>
                    </div>
                  ))}
                  {userTransactions.length > 5 && (
                    <div style={{ textAlign: 'center', fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.5rem' }}>
                      Showing 5 of {userTransactions.length}
                    </div>
                  )}
                </div>
              )}
            </div>

            <div style={{ display: 'flex', gap: '1rem' }}>
              <button 
                className={`btn ${selectedUser.enabled ? 'btn-danger' : 'btn-success'}`} 
                style={{ flex: 1 }}
                onClick={(e) => selectedUser.enabled ? handleBanUser(selectedUser.id, e) : handleUnbanUser(selectedUser.id, e)}
              >
                {selectedUser.enabled ? 'Ban User' : 'Unban User'}
              </button>
            </div>
          </div>
        )}
      </SlideOutPanel>
    </div>
  );
}

export default Users;
