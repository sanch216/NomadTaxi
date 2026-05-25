package com.aistaxi.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class WeatherForecastDTO {
    private LocalDate date;
    private double avgTemperature;
    private double totalRainMm;
    private double totalSnowfallCm;
    private BigDecimal expectedSurge;
    private String summary;
}
