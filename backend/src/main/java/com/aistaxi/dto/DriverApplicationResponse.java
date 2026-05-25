package com.aistaxi.dto;

import com.aistaxi.model.ApplicationStatus;
import com.aistaxi.model.CarClass;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DriverApplicationResponse {
    private Long id;
    private String fullName;
    private String phone;
    private String email;
    private String licenseNumber;
    private String licenseExpiry;
    private String vehicleMake;
    private String vehicleModel;
    private Integer vehicleYear;
    private String vehiclePlate;
    private CarClass carClass;
    private ApplicationStatus status;
    private LocalDateTime submittedAt;
    private LocalDateTime reviewedAt;
    private String reviewedByName;
    private String rejectionReason;
    private String notes;
}
