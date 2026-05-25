package com.aistaxi.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class HeatmapCellDTO {
    private String cellId;
    private double lat;
    private double lon;
    private double weight;
}
