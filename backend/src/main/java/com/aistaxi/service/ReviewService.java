package com.aistaxi.service;

import com.aistaxi.model.*;
import com.aistaxi.repository.ReviewRepository;
import com.aistaxi.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final RideRepository rideRepository;
    private final AdminActionLogService adminActionLogService;

    @Transactional
    public Review createReview(Long rideId, User reviewer, Double rating, String comment) {
        Ride ride = rideRepository.findById(rideId)
            .orElseThrow(() -> new RuntimeException("Ride not found"));

        if (ride.getStatus() != RideStatus.COMPLETED) {
            throw new RuntimeException("Can only review completed rides");
        }

        boolean isDriver = ride.getDriver() != null && ride.getDriver().getId().equals(reviewer.getId());
        boolean isClient = ride.getClient().getId().equals(reviewer.getId());

        if (!isDriver && !isClient) {
            throw new RuntimeException("Only ride participants can leave reviews");
        }

        if (reviewRepository.findByRideIdAndReviewerId(rideId, reviewer.getId()).isPresent()) {
            throw new RuntimeException("You have already reviewed this ride");
        }

        if (rating < 1.0 || rating > 5.0) {
            throw new RuntimeException("Rating must be between 1.0 and 5.0");
        }

        Review review = new Review();
        review.setRide(ride);
        review.setReviewer(reviewer);

        if (isDriver) {
            review.setReviewee(ride.getClient());
            review.setType(ReviewType.DRIVER_TO_CLIENT);
        } else {
            review.setReviewee(ride.getDriver());
            review.setType(ReviewType.CLIENT_TO_DRIVER);
        }

        review.setRating(rating);
        review.setComment(comment);

        return reviewRepository.save(review);
    }

    public Page<Review> getReviewsForUser(Long userId, boolean onlyVisible, Pageable pageable) {
        if (onlyVisible) {
            return reviewRepository.findByRevieweeIdAndIsVisibleTrue(userId, pageable);
        }
        return reviewRepository.findByRevieweeId(userId, pageable);
    }

    public List<Review> getReviewsForUser(Long userId, boolean onlyVisible) {
        if (onlyVisible) {
            return reviewRepository.findVisibleReviewsForUser(userId);
        }
        return reviewRepository.findByRevieweeId(userId, Pageable.unpaged()).getContent();
    }

    public Page<Review> getReviewsByUser(Long userId, Pageable pageable) {
        return reviewRepository.findByReviewerId(userId, pageable);
    }

    public List<Review> getReviewsByUser(Long userId) {
        return reviewRepository.findByReviewerId(userId, Pageable.unpaged()).getContent();
    }

    public List<Review> getReviewsForRide(Long rideId) {
        return reviewRepository.findByRideId(rideId);
    }

    public Page<Review> getFlaggedReviews(Pageable pageable) {
        return reviewRepository.findByIsFlaggedTrue(pageable);
    }

    public Review getReviewById(Long id) {
        return reviewRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Review not found"));
    }

    public Page<Review> getAllReviews(Pageable pageable) {
        return reviewRepository.findAll(pageable);
    }

    @Transactional
    public Review hideReview(Long reviewId, User admin, String reason) {
        Review review = getReviewById(reviewId);

        review.setIsVisible(false);
        review.setModeratedBy(admin);
        review.setModeratedAt(LocalDateTime.now());
        review.setFlagReason(reason);

        Review saved = reviewRepository.save(review);

        adminActionLogService.log(
            admin,
            ActionType.MODERATE_REVIEW,
            "Review:" + reviewId,
            "Hidden review: " + reason
        );

        return saved;
    }

    @Transactional
    public Review showReview(Long reviewId, User admin) {
        Review review = getReviewById(reviewId);

        review.setIsVisible(true);
        review.setModeratedBy(admin);
        review.setModeratedAt(LocalDateTime.now());

        Review saved = reviewRepository.save(review);

        adminActionLogService.log(
            admin,
            ActionType.MODERATE_REVIEW,
            "Review:" + reviewId,
            "Restored review visibility"
        );

        return saved;
    }

    @Transactional
    public Review flagReview(Long reviewId, String reason) {
        Review review = getReviewById(reviewId);

        review.setIsFlagged(true);
        review.setFlagReason(reason);

        return reviewRepository.save(review);
    }

    @Transactional
    public Review unflagReview(Long reviewId, User admin) {
        Review review = getReviewById(reviewId);

        review.setIsFlagged(false);
        review.setFlagReason(null);
        review.setModeratedBy(admin);
        review.setModeratedAt(LocalDateTime.now());

        Review saved = reviewRepository.save(review);

        adminActionLogService.log(
            admin,
            ActionType.MODERATE_REVIEW,
            "Review:" + reviewId,
            "Unflagged review"
        );

        return saved;
    }

    @Transactional
    public void deleteReview(Long reviewId, User admin) {
        Review review = getReviewById(reviewId);

        reviewRepository.delete(review);

        adminActionLogService.log(
            admin,
            ActionType.DELETE_REVIEW,
            "Review:" + reviewId,
            "Deleted review for ride " + review.getRide().getId()
        );
    }

    public Double getAverageRating(Long userId) {
        Double avg = reviewRepository.getAverageRatingForUser(userId);
        return avg != null ? avg : 0.0;
    }

    public Long getReviewCount(Long userId) {
        return reviewRepository.getReviewCountForUser(userId);
    }
}
