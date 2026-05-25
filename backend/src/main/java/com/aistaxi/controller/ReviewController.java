package com.aistaxi.controller;

import com.aistaxi.dto.ReviewRequest;
import com.aistaxi.dto.ReviewResponse;
import com.aistaxi.model.Review;
import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.service.ReviewService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/reviews")
@RequiredArgsConstructor
public class ReviewController {

    private final ReviewService reviewService;
    private final UserRepository userRepository;

    private User getUser(UserDetails userDetails) {
        return userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    @PostMapping
    public ResponseEntity<?> createReview(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody ReviewRequest request) {

        try {
            User user = getUser(userDetails);
            Review review = reviewService.createReview(
                request.getRideId(),
                user,
                request.getRating(),
                request.getComment()
            );

            return ResponseEntity.ok(mapToResponse(review));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<List<ReviewResponse>> getUserReviews(@PathVariable Long userId) {
        List<Review> reviews = reviewService.getReviewsForUser(userId, true);
        List<ReviewResponse> result = reviews.stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @GetMapping("/my-reviews")
    public ResponseEntity<List<ReviewResponse>> getMyReviews(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        List<Review> reviews = reviewService.getReviewsByUser(user.getId());
        List<ReviewResponse> result = reviews.stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @GetMapping("/ride/{rideId}")
    public ResponseEntity<List<ReviewResponse>> getRideReviews(@PathVariable Long rideId) {
        List<Review> reviews = reviewService.getReviewsForRide(rideId);
        List<ReviewResponse> result = reviews.stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/{id}/flag")
    public ResponseEntity<?> flagReview(
            @PathVariable Long id,
            @RequestParam String reason) {

        try {
            Review review = reviewService.flagReview(id, reason);
            return ResponseEntity.ok(mapToResponse(review));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/stats/{userId}")
    public ResponseEntity<Map<String, Object>> getUserReviewStats(@PathVariable Long userId) {
        Double avgRating = reviewService.getAverageRating(userId);
        Long reviewCount = reviewService.getReviewCount(userId);

        return ResponseEntity.ok(Map.of(
            "userId", userId,
            "averageRating", avgRating,
            "reviewCount", reviewCount
        ));
    }

    private ReviewResponse mapToResponse(Review review) {
        ReviewResponse response = new ReviewResponse();
        response.setId(review.getId());
        response.setRideId(review.getRide().getId());
        response.setReviewerId(review.getReviewer().getId());
        response.setReviewerName(review.getReviewer().getFullName());
        response.setRevieweeId(review.getReviewee().getId());
        response.setRevieweeName(review.getReviewee().getFullName());
        response.setType(review.getType());
        response.setRating(review.getRating());
        response.setComment(review.getComment());
        response.setIsVisible(review.getIsVisible());
        response.setIsFlagged(review.getIsFlagged());
        response.setFlagReason(review.getFlagReason());

        if (review.getModeratedBy() != null) {
            response.setModeratedByName(review.getModeratedBy().getFullName());
        }

        response.setModeratedAt(review.getModeratedAt());
        response.setCreatedAt(review.getCreatedAt());

        return response;
    }
}
