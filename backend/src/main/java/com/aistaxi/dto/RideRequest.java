package com.aistaxi.dto;

import com.aistaxi.model.CarClass;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class RideRequest {
    private String pickupAddress;
    private Double pickupLat;
    private Double pickupLon;
    private String dropoffAddress;
    private Double dropoffLat;
    private Double dropoffLon;
    private CarClass requestedCarClass;
    private Double distanceKm; // changed here
    private String comment;
}
