package com.aistaxi.dto;

import com.aistaxi.model.TicketCategory;
import lombok.Data;

@Data
public class TicketRequest {
    private String subject;
    private String description;
    private TicketCategory category;
    private Long rideId;
}
