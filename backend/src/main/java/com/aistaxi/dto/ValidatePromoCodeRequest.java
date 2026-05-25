package com.aistaxi.dto;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class ValidatePromoCodeRequest {
    private String code;
    private BigDecimal rideAmount;
}
