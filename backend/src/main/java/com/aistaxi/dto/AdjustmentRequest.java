package com.aistaxi.dto;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class AdjustmentRequest {
    private Long userId;
    private BigDecimal amount;
    private String reason;
}
