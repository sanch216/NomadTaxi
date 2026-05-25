import { useEffect, useState } from 'react';
import { auditLogsService } from '../services/api';
import { AuditLog } from '../types';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useToast } from '../components/Toast';
import '../pages/Users.css';

function AuditLogs() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;

  const toast = useToast();

  useEffect(() => {
    loadLogs();
  }, [currentPage]);

  const loadLogs = async () => {
    setLoading(true);
    try {
      const params = { 
        page: currentPage, 
        size: pageSize 
      };
      const response = await auditLogsService.getLogs(params);
      
      if (response.data.content) {
        setLogs(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        const data = Array.isArray(response.data) ? response.data : [];
        setLogs(data);
        setTotalPages(1);
        setTotalElements(data.length);
      }
    } catch (error) {
      console.error('Failed to load audit logs:', error);
      toast.error('Failed to load audit logs');
    } finally {
      setLoading(false);
    }
  };

  const filteredLogs = logs.filter(log => 
    log.adminName?.toLowerCase().includes(searchQuery.toLowerCase()) || 
    log.action?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    log.target?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    log.details?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const renderSkeleton = () => (
    <>
      {[...Array(8)].map((_, i) => (
        <tr key={i}>
          {[...Array(6)].map((_, j) => (
            <td key={j}><div className="skeleton-cell" style={{ width: `${40 + Math.random() * 50}%`, height: '1rem' }} /></td>
          ))}
        </tr>
      ))}
    </>
  );

  return (
    <div className="users-page">
      <div className="page-header" style={{ marginBottom: '1rem' }}>
        <h1>Audit Logs</h1>
      </div>

      <div className="table-header-controls">
        <div className="search-bar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input 
            type="text" 
            placeholder="Search by Admin, Action or Target..." 
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
              <th>Admin</th>
              <th>Action</th>
              <th>Target</th>
              <th>Details</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : filteredLogs.length === 0 ? (
              <tr>
                <td colSpan={6}>
                  <EmptyState icon="logs" title="No audit logs" description="No admin actions have been recorded yet" />
                </td>
              </tr>
            ) : (
              filteredLogs.map((log) => (
                <tr key={log.id}>
                  <td>#{log.id}</td>
                  <td>
                    <strong>{log.adminName}</strong><br/>
                    <span style={{color: 'var(--text-muted)', fontSize: '0.8rem'}}>{log.adminPhone}</span>
                  </td>
                  <td>
                    <span className="badge badge-info">{log.action}</span>
                  </td>
                  <td>{log.target}</td>
                  <td style={{ maxWidth: '300px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {log.details || '-'}
                  </td>
                  <td>{new Date(log.createdAt).toLocaleString()}</td>
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

export default AuditLogs;
