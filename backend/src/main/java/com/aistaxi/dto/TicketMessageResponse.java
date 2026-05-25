package com.aistaxi.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TicketMessageResponse {
    private Long id;
    private Long ticketId;
    private Long senderId;
    private String senderName;
    private String message;
    private Boolean isInternal;
    private LocalDateTime createdAt;
}
