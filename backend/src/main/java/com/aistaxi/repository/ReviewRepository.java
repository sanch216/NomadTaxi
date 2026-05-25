package com.aistaxi.repository;

import com.aistaxi.model.Review;
import com.aistaxi.model.ReviewType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ReviewRepository extends JpaRepository<Review, Long> {

    List<Review> findByRideId(Long rideId);

    Page<Review> findByReviewerId(Long reviewerId, Pageable pageable);

    Page<Review> findByRevieweeId(Long revieweeId, Pageable pageable);

    Page<Review> findByRevieweeIdAndIsVisibleTrue(Long revieweeId, Pageable pageable);

    Page<Review> findByType(ReviewType type, Pageable pageable);

    Page<Review> findByIsFlaggedTrue(Pageable pageable);

    Optional<Review> findByRideIdAndReviewerId(Long rideId, Long reviewerId);

    @Query("SELECT r FROM Review r WHERE r.reviewee.id = :userId AND r.isVisible = true ORDER BY r.createdAt DESC")
    List<Review> findVisibleReviewsForUser(Long userId);

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.reviewee.id = :userId AND r.isVisible = true")
    Double getAverageRatingForUser(Long userId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.reviewee.id = :userId AND r.isVisible = true")
    Long getReviewCountForUser(Long userId);
}
