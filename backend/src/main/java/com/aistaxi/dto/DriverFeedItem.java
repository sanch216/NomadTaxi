package com.aistaxi.dto;

import com.aistaxi.model.CarClass;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DriverFeedItem {
    private Long rideId;
    // private Double distanceToPickup; // deleting it, the real distance will be
    // calcualted in the frontend, when front receive the response, it uses google
    // maps api to calculate the distance
    private BigDecimal price;
    private CarClass carClass;
    private String pickupAddress;
    private Double pickupLat;
    private Double pickupLon;
    private String dropoffAddress;
    private Double dropoffLat;
    private Double dropoffLon;
}
