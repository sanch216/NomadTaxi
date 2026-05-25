package com.aistaxi.dto;

import com.aistaxi.model.ReviewType;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ReviewResponse {
    private Long id;
    private Long rideId;
    private Long reviewerId;
    private String reviewerName;
    private Long revieweeId;
    private String revieweeName;
    private ReviewType type;
    private Double rating;
    private String comment;
    private Boolean isVisible;
    private Boolean isFlagged;
    private String flagReason;
    private String moderatedByName;
    private LocalDateTime moderatedAt;
    private LocalDateTime createdAt;
}
