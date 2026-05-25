import { useEffect, useState } from 'react';
import { promoCodeService } from '../services/api';
import { PromoCode } from '../types';
import Modal from '../components/Modal';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useToast } from '../components/Toast';
import { useConfirm } from '../components/ConfirmDialog';
import '../pages/Users.css';

function PromoCodes() {
  const [promoCodes, setPromoCodes] = useState<PromoCode[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isCreating, setIsCreating] = useState(false);

  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;

  // Form state
  const [code, setCode] = useState('');
  const [type, setType] = useState('PERCENTAGE');
  const [discountValue, setDiscountValue] = useState('');
  const [usageLimit, setUsageLimit] = useState('');
  const [validFrom, setValidFrom] = useState('');
  const [validUntil, setValidUntil] = useState('');

  const toast = useToast();
  const confirm = useConfirm();

  useEffect(() => {
    loadPromoCodes();
  }, [currentPage]);

  const loadPromoCodes = async () => {
    setLoading(true);
    try {
      const params = { 
        page: currentPage, 
        size: pageSize 
      };
      const response = await promoCodeService.getPromoCodes(params);
      
      if (response.data.content) {
        setPromoCodes(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        const data = Array.isArray(response.data) ? response.data : [];
        setPromoCodes(data);
        setTotalPages(1);
        setTotalElements(data.length);
      }
    } catch (error) {
      console.error('Failed to load promo codes:', error);
      toast.error('Failed to load promo codes');
    } finally {
      setLoading(false);
    }
  };

  const handleDeactivate = async (id: number) => {
    const { confirmed } = await confirm({
      title: 'Deactivate Promo Code',
      message: 'Deactivate this promo code? Users will no longer be able to use it.',
      confirmText: 'Deactivate',
      variant: 'warning',
    });
    if (!confirmed) return;

    try {
      await promoCodeService.deactivatePromoCode(id);
      loadPromoCodes();
      toast.success('Promo code deactivated');
    } catch (error) {
      toast.error('Failed to deactivate promo code');
    }
  };

  const handleDelete = async (id: number) => {
    const { confirmed } = await confirm({
      title: 'Delete Promo Code',
      message: 'Delete this promo code? This action cannot be undone.',
      confirmText: 'Delete',
      variant: 'danger',
    });
    if (!confirmed) return;

    try {
      await promoCodeService.deletePromoCode(id);
      loadPromoCodes();
      toast.success('Promo code deleted');
    } catch (error) {
      toast.error('Failed to delete promo code');
    }
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsCreating(true);
    try {
      await promoCodeService.createPromoCode({
        code,
        type,
        discountValue: Number(discountValue),
        usageLimit: usageLimit ? Number(usageLimit) : null,
        validFrom: new Date(validFrom).toISOString(),
        validUntil: new Date(validUntil).toISOString()
      });
      toast.success('Promo code created successfully');
      setIsModalOpen(false);
      
      // Reset form
      setCode('');
      setDiscountValue('');
      setUsageLimit('');
      setValidFrom('');
      setValidUntil('');
      
      loadPromoCodes();
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Failed to create promo code');
    } finally {
      setIsCreating(false);
    }
  };

  const renderSkeleton = () => (
    <>
      {[...Array(5)].map((_, i) => (
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
        <h1>Promo Codes</h1>
        <button className="btn btn-primary" onClick={() => setIsModalOpen(true)}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ marginRight: '8px' }}>
            <line x1="12" y1="5" x2="12" y2="19"></line>
            <line x1="5" y1="12" x2="19" y2="12"></line>
          </svg>
          Create Promo Code
        </button>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Code</th>
              <th>Type</th>
              <th>Discount</th>
              <th>Usage</th>
              <th>Valid Period</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : promoCodes.length === 0 ? (
              <tr>
                <td colSpan={7}>
                  <EmptyState icon="promo" title="No promo codes" description="Create your first promo code to get started" />
                </td>
              </tr>
            ) : (
              promoCodes.map((promo) => (
                <tr key={promo.id}>
                  <td><span className="badge badge-info" style={{fontSize: '0.875rem'}}>{promo.code}</span></td>
                  <td>{promo.type}</td>
                  <td>
                    {promo.type === 'PERCENTAGE'
                      ? `${promo.discountValue}%`
                      : `$${promo.discountValue}`}
                  </td>
                  <td>
                    {promo.usageCount} / {promo.usageLimit || '∞'}
                  </td>
                  <td>
                    {new Date(promo.validFrom).toLocaleDateString()} - {new Date(promo.validUntil).toLocaleDateString()}
                  </td>
                  <td>
                    {promo.active ? (
                      <span className="badge badge-success">Active</span>
                    ) : (
                      <span className="badge badge-danger">Inactive</span>
                    )}
                  </td>
                  <td>
                    {promo.active && (
                      <button
                        className="btn btn-warning btn-sm"
                        onClick={() => handleDeactivate(promo.id)}
                      >
                        Deactivate
                      </button>
                    )}
                    <button
                      className="btn btn-danger btn-sm"
                      onClick={() => handleDelete(promo.id)}
                    >
                      Delete
                    </button>
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

      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Create New Promo Code"
      >
        <form onSubmit={handleCreate}>
          <div className="form-group">
            <label>Code (e.g. SUMMER2026)</label>
            <input 
              type="text" 
              value={code} 
              onChange={e => setCode(e.target.value.toUpperCase())} 
              required 
              placeholder="Enter promo code"
            />
          </div>
          <div className="form-group">
            <label>Type</label>
            <select value={type} onChange={e => setType(e.target.value)}>
              <option value="PERCENTAGE">Percentage (%)</option>
              <option value="FIXED_AMOUNT">Fixed Amount ($)</option>
            </select>
          </div>
          <div className="form-group">
            <label>Discount Value</label>
            <input 
              type="number" 
              step="0.01"
              value={discountValue} 
              onChange={e => setDiscountValue(e.target.value)} 
              required 
              placeholder="e.g. 10"
            />
          </div>
          <div className="form-group">
            <label>Usage Limit (Optional)</label>
            <input 
              type="number" 
              value={usageLimit} 
              onChange={e => setUsageLimit(e.target.value)} 
              placeholder="Leave empty for unlimited"
            />
          </div>
          <div className="form-group">
            <label>Valid From</label>
            <input 
              type="datetime-local" 
              value={validFrom} 
              onChange={e => setValidFrom(e.target.value)} 
              required 
            />
          </div>
          <div className="form-group">
            <label>Valid Until</label>
            <input 
              type="datetime-local" 
              value={validUntil} 
              onChange={e => setValidUntil(e.target.value)} 
              required 
            />
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={() => setIsModalOpen(false)}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" disabled={isCreating}>
              {isCreating ? 'Creating...' : 'Create Promo Code'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

export default PromoCodes;
