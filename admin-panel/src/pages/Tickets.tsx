import { useEffect, useState } from 'react';
import { ticketService } from '../services/api';
import { SupportTicket } from '../types';
import Modal from '../components/Modal';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useToast } from '../components/Toast';
import { useConfirm } from '../components/ConfirmDialog';
import '../pages/Users.css';

function Tickets() {
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'ALL' | 'OPEN' | 'IN_PROGRESS' | 'RESOLVED'>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;

  // Resolve Modal
  const [isResolveModalOpen, setIsResolveModalOpen] = useState(false);
  const [resolvingTicketId, setResolvingTicketId] = useState<number | null>(null);
  const [resolutionNotes, setResolutionNotes] = useState('');

  // Priority Modal
  const [isPriorityModalOpen, setIsPriorityModalOpen] = useState(false);
  const [priorityTicketId, setPriorityTicketId] = useState<number | null>(null);
  const [newPriority, setNewPriority] = useState('LOW');

  const toast = useToast();
  const confirm = useConfirm();

  useEffect(() => {
    setCurrentPage(0);
  }, [filter]);

  useEffect(() => {
    loadTickets();
  }, [filter, currentPage]);

  const loadTickets = async () => {
    setLoading(true);
    try {
      const params: any = { 
        page: currentPage, 
        size: pageSize 
      };
      if (filter !== 'ALL') params.status = filter;
      
      const response = await ticketService.getTickets(params);
      
      if (response.data.content) {
        setTickets(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        const data = Array.isArray(response.data) ? response.data : [];
        setTickets(data);
        setTotalPages(1);
        setTotalElements(data.length);
      }
    } catch (error) {
      console.error('Failed to load tickets:', error);
      toast.error('Failed to load tickets');
    } finally {
      setLoading(false);
    }
  };

  const handleResolveSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!resolvingTicketId) return;

    try {
      await ticketService.resolveTicket(resolvingTicketId, resolutionNotes);
      loadTickets();
      toast.success('Ticket resolved');
      setIsResolveModalOpen(false);
      setResolutionNotes('');
    } catch (error) {
      toast.error('Failed to resolve ticket');
    }
  };

  const handleClose = async (id: number) => {
    const { confirmed } = await confirm({
      title: 'Close Ticket',
      message: `Close ticket #${id}? This action cannot be undone.`,
      confirmText: 'Close Ticket',
      variant: 'warning',
    });
    if (!confirmed) return;

    try {
      await ticketService.closeTicket(id);
      loadTickets();
      toast.success('Ticket closed');
    } catch (error) {
      toast.error('Failed to close ticket');
    }
  };

  const handlePrioritySubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!priorityTicketId) return;

    try {
      await ticketService.updatePriority(priorityTicketId, newPriority);
      loadTickets();
      toast.success('Priority updated');
      setIsPriorityModalOpen(false);
    } catch (error) {
      toast.error('Failed to update priority');
    }
  };

  const filteredTickets = tickets.filter(t => 
    t.userName?.toLowerCase().includes(searchQuery.toLowerCase()) || 
    t.subject?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.id.toString().includes(searchQuery)
  );

  const renderSkeleton = () => (
    <>
      {[...Array(6)].map((_, i) => (
        <tr key={i}>
          {[...Array(9)].map((_, j) => (
            <td key={j}><div className="skeleton-cell" style={{ width: `${40 + Math.random() * 50}%`, height: '1rem' }} /></td>
          ))}
        </tr>
      ))}
    </>
  );

  return (
    <div className="users-page">
      <div className="page-header" style={{ marginBottom: '1rem' }}>
        <h1>Support Tickets</h1>
      </div>

      <div className="table-header-controls">
        <div className="search-bar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input 
            type="text" 
            placeholder="Search by ID, user or subject..." 
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div className="filter-buttons">
          <button className={filter === 'ALL' ? 'active' : ''} onClick={() => setFilter('ALL')}>All</button>
          <button className={filter === 'OPEN' ? 'active' : ''} onClick={() => setFilter('OPEN')}>Open</button>
          <button className={filter === 'IN_PROGRESS' ? 'active' : ''} onClick={() => setFilter('IN_PROGRESS')}>In Progress</button>
          <button className={filter === 'RESOLVED' ? 'active' : ''} onClick={() => setFilter('RESOLVED')}>Resolved</button>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>User</th>
              <th>Subject</th>
              <th>Category</th>
              <th>Priority</th>
              <th>Status</th>
              <th>Assigned To</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : filteredTickets.length === 0 ? (
              <tr>
                <td colSpan={9}>
                  <EmptyState icon="tickets" title="No tickets found" description="No support tickets match the current filter" />
                </td>
              </tr>
            ) : (
              filteredTickets.map((ticket) => (
                <tr key={ticket.id}>
                  <td>#{ticket.id}</td>
                  <td><strong>{ticket.userName}</strong></td>
                  <td>{ticket.subject}</td>
                  <td>
                    <span className="badge badge-info">
                      {ticket.category}
                    </span>
                  </td>
                  <td>
                    <span className={`badge badge-${ticket.priority.toLowerCase()}`}>
                      {ticket.priority}
                    </span>
                  </td>
                  <td>
                    <span className={`badge badge-${ticket.status.toLowerCase()}`}>
                      {ticket.status}
                    </span>
                  </td>
                  <td>{ticket.assignedToName || '-'}</td>
                  <td>{new Date(ticket.createdAt).toLocaleString()}</td>
                  <td>
                    {ticket.status === 'OPEN' || ticket.status === 'IN_PROGRESS' ? (
                      <>
                        <button
                          className="btn btn-success btn-sm"
                          onClick={() => {
                            setResolvingTicketId(ticket.id);
                            setIsResolveModalOpen(true);
                          }}
                          style={{ marginRight: '5px' }}
                        >
                          Resolve
                        </button>
                        <button
                          className="btn btn-warning btn-sm"
                          onClick={() => {
                            setPriorityTicketId(ticket.id);
                            setNewPriority(ticket.priority);
                            setIsPriorityModalOpen(true);
                          }}
                          style={{ marginRight: '5px' }}
                        >
                          Priority
                        </button>
                      </>
                    ) : null}
                    {ticket.status === 'RESOLVED' && (
                      <button
                        className="btn btn-danger btn-sm"
                        onClick={() => handleClose(ticket.id)}
                      >
                        Close
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

      {/* Resolve Modal */}
      <Modal
        isOpen={isResolveModalOpen}
        onClose={() => setIsResolveModalOpen(false)}
        title="Resolve Ticket"
      >
        <form onSubmit={handleResolveSubmit}>
          <div className="form-group">
            <label>Resolution Notes</label>
            <textarea 
              value={resolutionNotes} 
              onChange={e => setResolutionNotes(e.target.value)} 
              required 
              placeholder="Explain how the issue was resolved..."
              rows={4}
            />
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={() => setIsResolveModalOpen(false)}>
              Cancel
            </button>
            <button type="submit" className="btn btn-success">
              Mark as Resolved
            </button>
          </div>
        </form>
      </Modal>

      {/* Priority Modal */}
      <Modal
        isOpen={isPriorityModalOpen}
        onClose={() => setIsPriorityModalOpen(false)}
        title="Update Ticket Priority"
      >
        <form onSubmit={handlePrioritySubmit}>
          <div className="form-group">
            <label>New Priority Level</label>
            <select value={newPriority} onChange={e => setNewPriority(e.target.value)}>
              <option value="LOW">Low</option>
              <option value="MEDIUM">Medium</option>
              <option value="HIGH">High</option>
              <option value="URGENT">Urgent</option>
            </select>
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={() => setIsPriorityModalOpen(false)}>
              Cancel
            </button>
            <button type="submit" className="btn btn-warning">
              Update Priority
            </button>
          </div>
        </form>
      </Modal>

    </div>
  );
}

export default Tickets;
