package com.aistaxi.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class EarningsSummaryDto {
    private BigDecimal todayEarnings;
    private BigDecimal weekEarnings;
    private Integer totalRides;
}
