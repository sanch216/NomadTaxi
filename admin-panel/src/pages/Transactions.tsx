import { useEffect, useState } from 'react';
import { transactionService } from '../services/api';
import { Transaction } from '../types';
import Modal from '../components/Modal';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useToast } from '../components/Toast';
import '../pages/Users.css';

function Transactions() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;
  
  // Modal state
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  
  // Form state
  const [userId, setUserId] = useState('');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');

  const toast = useToast();

  useEffect(() => {
    loadTransactions();
  }, [currentPage]);

  const loadTransactions = async () => {
    setLoading(true);
    try {
      const params = { 
        page: currentPage, 
        size: pageSize 
      };
      const response = await transactionService.getTransactions(params);
      
      if (response.data.content) {
        setTransactions(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        const data = Array.isArray(response.data) ? response.data : [];
        setTransactions(data);
        setTotalPages(1);
        setTotalElements(data.length);
      }
    } catch (error) {
      console.error('Failed to load transactions:', error);
      toast.error('Failed to load transactions');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateAdjustment = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsCreating(true);
    try {
      await transactionService.createAdjustment({
        userId: Number(userId),
        amount: Number(amount),
        reason: description
      });
      toast.success('Adjustment created successfully');
      setIsModalOpen(false);
      
      // Reset form
      setUserId('');
      setAmount('');
      setDescription('');
      
      loadTransactions();
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Failed to create adjustment');
    } finally {
      setIsCreating(false);
    }
  };

  const filteredTransactions = transactions.filter(t => 
    t.userName?.toLowerCase().includes(searchQuery.toLowerCase()) || 
    t.userPhone?.includes(searchQuery) ||
    t.description?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const renderSkeleton = () => (
    <>
      {[...Array(8)].map((_, i) => (
        <tr key={i}>
          {[...Array(7)].map((_, j) => (
            <td key={j}><div className="skeleton-cell" style={{ width: `${40 + Math.random() * 50}%`, height: '1rem' }} /></td>
          ))}
        </tr>
      ))}
    </>
  );

  return (
    <div className="users-page">
      <div className="page-header" style={{ marginBottom: '1rem' }}>
        <h1>Transactions</h1>
        <button className="btn btn-primary" onClick={() => setIsModalOpen(true)}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ marginRight: '8px' }}>
            <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
          </svg>
          Create Adjustment
        </button>
      </div>

      <div className="table-header-controls">
        <div className="search-bar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input 
            type="text" 
            placeholder="Search by user, phone or desc..." 
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Type</th>
              <th>User</th>
              <th>Amount</th>
              <th>Status</th>
              <th>Description</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : filteredTransactions.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <EmptyState icon="transactions" title="No transactions found" description="No transactions match the current search" />
                </td>
              </tr>
            ) : (
              filteredTransactions.map((transaction) => (
                <tr key={transaction.id}>
                  <td>#{transaction.id}</td>
                  <td>
                    <span className="badge badge-info">
                      {transaction.type}
                    </span>
                  </td>
                  <td>
                    <strong>{transaction.userName || 'System'}</strong><br />
                    <span style={{color: 'var(--text-muted)', fontSize: '0.875rem'}}>{transaction.userPhone}</span>
                  </td>
                  <td style={{ color: transaction.amount > 0 ? 'var(--success)' : 'var(--danger)', fontWeight: 'bold' }}>
                    {transaction.amount > 0 ? '+' : ''}{transaction.amount.toFixed(2)}
                  </td>
                  <td>
                    <span className={`badge badge-${transaction.status.toLowerCase()}`}>
                      {transaction.status}
                    </span>
                  </td>
                  <td>{transaction.description}</td>
                  <td>{new Date(transaction.createdAt).toLocaleString()}</td>
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

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Create Balance Adjustment"
      >
        <form onSubmit={handleCreateAdjustment}>
          <div className="form-group">
            <label>User ID</label>
            <input 
              type="number" 
              value={userId} 
              onChange={e => setUserId(e.target.value)} 
              required 
              placeholder="Enter User ID"
            />
          </div>
          <div className="form-group">
            <label>Amount (Use negative for deduction)</label>
            <input 
              type="number" 
              step="0.01"
              value={amount} 
              onChange={e => setAmount(e.target.value)} 
              required 
              placeholder="e.g. 50.00 or -25.00"
            />
          </div>
          <div className="form-group">
            <label>Description</label>
            <textarea 
              value={description} 
              onChange={e => setDescription(e.target.value)} 
              required 
              placeholder="Reason for adjustment..."
              rows={3}
            />
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={() => setIsModalOpen(false)}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" disabled={isCreating}>
              {isCreating ? 'Processing...' : 'Create Adjustment'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

export default Transactions;
