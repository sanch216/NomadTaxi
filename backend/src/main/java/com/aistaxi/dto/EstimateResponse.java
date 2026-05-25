package com.aistaxi.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class EstimateResponse {
    private String carClass;
    private double price;
    private int arrivalTime; // minutes
}
