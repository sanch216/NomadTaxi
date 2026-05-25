import { useEffect, useState } from 'react';
import { reviewService } from '../services/api';
import { Review } from '../types';
import Modal from '../components/Modal';
import Pagination from '../components/Pagination';
import EmptyState from '../components/EmptyState';
import { useToast } from '../components/Toast';
import { useConfirm } from '../components/ConfirmDialog';
import '../pages/Users.css';

function Reviews() {
  const [reviews, setReviews] = useState<Review[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'ALL' | 'FLAGGED'>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  // Pagination
  const [currentPage, setCurrentPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const pageSize = 20;

  const [isHideModalOpen, setIsHideModalOpen] = useState(false);
  const [hidingReviewId, setHidingReviewId] = useState<number | null>(null);
  const [hideReason, setHideReason] = useState('');

  const toast = useToast();
  const confirm = useConfirm();

  useEffect(() => {
    loadReviews();
  }, [filter, currentPage]);

  const loadReviews = async () => {
    setLoading(true);
    try {
      const params: any = { 
        page: currentPage, 
        size: pageSize 
      };
      if (filter === 'FLAGGED') params.flagged = true;
      
      const response = await reviewService.getReviews(params);
      
      if (response.data.content) {
        setReviews(response.data.content);
        setTotalPages(response.data.totalPages);
        setTotalElements(response.data.totalElements);
      } else {
        const data = Array.isArray(response.data) ? response.data : [];
        setReviews(data);
        setTotalPages(1);
        setTotalElements(data.length);
      }
    } catch (error) {
      console.error('Failed to load reviews:', error);
      toast.error('Failed to load reviews');
    } finally {
      setLoading(false);
    }
  };

  const submitHide = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!hidingReviewId) return;

    try {
      await reviewService.hideReview(hidingReviewId, hideReason);
      loadReviews();
      toast.success('Review hidden');
      setIsHideModalOpen(false);
      setHideReason('');
    } catch (error) {
      toast.error('Failed to hide review');
    }
  };

  const handleShow = async (id: number) => {
    try {
      await reviewService.showReview(id);
      loadReviews();
      toast.success('Review restored');
    } catch (error) {
      toast.error('Failed to restore review');
    }
  };

  const handleDelete = async (id: number) => {
    const { confirmed } = await confirm({
      title: 'Delete Review',
      message: 'Delete this review? This action cannot be undone.',
      confirmText: 'Delete',
      variant: 'danger',
    });
    if (!confirmed) return;

    try {
      await reviewService.deleteReview(id);
      loadReviews();
      toast.success('Review deleted');
    } catch (error) {
      toast.error('Failed to delete review');
    }
  };

  const filteredReviews = reviews.filter(r => 
    r.reviewerName?.toLowerCase().includes(searchQuery.toLowerCase()) || 
    r.revieweeName?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    r.comment?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    r.id.toString().includes(searchQuery)
  );

  const renderSkeleton = () => (
    <>
      {[...Array(6)].map((_, i) => (
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
      <div className="page-header" style={{ marginBottom: '1rem' }}>
        <h1>Reviews Moderation</h1>
      </div>

      <div className="table-header-controls">
        <div className="search-bar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input 
            type="text" 
            placeholder="Search by ID, name or comment..." 
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div className="filter-buttons">
          <button className={filter === 'ALL' ? 'active' : ''} onClick={() => setFilter('ALL')}>All</button>
          <button className={filter === 'FLAGGED' ? 'active' : ''} onClick={() => setFilter('FLAGGED')}>Flagged</button>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Ride</th>
              <th>Reviewer</th>
              <th>Reviewee</th>
              <th>Rating</th>
              <th>Comment</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? renderSkeleton() : filteredReviews.length === 0 ? (
              <tr>
                <td colSpan={8}>
                  <EmptyState icon="reviews" title="No reviews found" description="No reviews match the current filter" />
                </td>
              </tr>
            ) : (
              filteredReviews.map((review) => (
                <tr key={review.id} style={{ opacity: review.isVisible ? 1 : 0.6 }}>
                  <td>#{review.id}</td>
                  <td><span className="badge badge-info">Ride #{review.rideId}</span></td>
                  <td><strong>{review.reviewerName || 'Unknown'}</strong></td>
                  <td>{review.revieweeName || 'Unknown'}</td>
                  <td style={{ color: 'var(--warning)', fontWeight: 'bold' }}>⭐ {review.rating.toFixed(1)}</td>
                  <td style={{ maxWidth: '300px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {review.comment || <span style={{ color: 'var(--text-muted)' }}>No comment</span>}
                  </td>
                  <td>
                    {review.isFlagged && (
                      <span className="badge badge-danger" style={{ marginRight: '4px' }}>Flagged</span>
                    )}
                    {!review.isVisible && (
                      <span className="badge badge-warning">Hidden</span>
                    )}
                    {review.isVisible && !review.isFlagged && (
                      <span className="badge badge-success">Visible</span>
                    )}
                  </td>
                  <td>
                    {review.isVisible ? (
                      <button
                        className="btn btn-warning btn-sm"
                        onClick={() => {
                          setHidingReviewId(review.id);
                          setIsHideModalOpen(true);
                        }}
                        style={{ marginRight: '5px' }}
                      >
                        Hide
                      </button>
                    ) : (
                      <button
                        className="btn btn-success btn-sm"
                        onClick={() => handleShow(review.id)}
                        style={{ marginRight: '5px' }}
                      >
                        Show
                      </button>
                    )}
                    <button
                      className="btn btn-danger btn-sm"
                      onClick={() => handleDelete(review.id)}
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
        isOpen={isHideModalOpen}
        onClose={() => setIsHideModalOpen(false)}
        title="Hide Review"
      >
        <form onSubmit={submitHide}>
          <div className="form-group">
            <label>Reason for Hiding</label>
            <textarea 
              value={hideReason} 
              onChange={e => setHideReason(e.target.value)} 
              required 
              placeholder="e.g. Inappropriate language, spam..."
              rows={3}
            />
          </div>
          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={() => setIsHideModalOpen(false)}>
              Cancel
            </button>
            <button type="submit" className="btn btn-warning">
              Hide Review
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}

export default Reviews;
