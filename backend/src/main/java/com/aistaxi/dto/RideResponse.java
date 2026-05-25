package com.aistaxi.dto;

import com.aistaxi.model.CarClass;
import com.aistaxi.model.RideStatus;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class RideResponse {
    private Long id;
    private RideStatus status;
    private String pickupAddress;
    private Double pickupLat;
    private Double pickupLon;
    private String dropoffAddress;
    private Double dropoffLat;
    private Double dropoffLon;
    private BigDecimal price;
    private CarClass requestedCarClass;
    private LocalDateTime createdAt;

    // Driver Info (if assigned)
    private String driverName;
    private String driverPhone;
    private String carNumber;
    private String carModel;
    private Double driverLat;
    private Double driverLon;

    // Surge pricing
    private BigDecimal surgeMultiplier;
    private BigDecimal weatherSurgeMultiplier;

    // Passenger comment
    private String comment;

    // Cancellation info
    private String cancellationReason;
    private String cancelledByName;

    // Promo code and discount
    private Long promoCodeId;
    private BigDecimal discountAmount;

    // Refund info
    private BigDecimal refundAmount;
    private LocalDateTime refundedAt;
}
