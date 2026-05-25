package com.aistaxi.dto;

import com.aistaxi.model.PromoCodeType;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class PromoCodeRequest {
    private String code;
    private PromoCodeType type;
    private BigDecimal discountValue;
    private BigDecimal maxDiscountAmount;
    private BigDecimal minRideAmount;
    private Integer usageLimit;
    private Integer perUserLimit;
    private LocalDateTime validFrom;
    private LocalDateTime validUntil;
    private Boolean active;
    private String description;
}
