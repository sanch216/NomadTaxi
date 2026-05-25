package com.aistaxi.dto;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class RefundRequest {
    private Long rideId;
    private BigDecimal amount;
    private String reason;
}
