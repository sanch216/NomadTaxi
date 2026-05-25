package com.aistaxi.dto;

import lombok.Data;

@Data
public class EstimateRequest {
    private double pickupLat;
    private double pickupLon;
    private double dropoffLat;
    private double dropoffLon;
}
