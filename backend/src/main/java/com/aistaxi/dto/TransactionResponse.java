package com.aistaxi.dto;

import com.aistaxi.model.TransactionStatus;
import com.aistaxi.model.TransactionType;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TransactionResponse {
    private Long id;
    private TransactionType type;
    private Long userId;
    private String userPhone;
    private String userName;
    private Long rideId;
    private BigDecimal amount;
    private TransactionStatus status;
    private String description;
    private String referenceId;
    private String paymentMethod;
    private String processedByName;
    private LocalDateTime createdAt;
    private LocalDateTime completedAt;
    private String failedReason;
}
