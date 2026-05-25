package com.aistaxi.dto;

import lombok.Data;

@Data
public class ReviewRequest {
    private Long rideId;
    private Double rating;
    private String comment;
}
