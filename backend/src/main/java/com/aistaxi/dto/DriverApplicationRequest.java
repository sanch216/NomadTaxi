package com.aistaxi.dto;

import com.aistaxi.model.CarClass;
import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class DriverApplicationRequest {
    @NotBlank(message = "Full name is required")
    @Size(min = 2, max = 100, message = "Full name must be between 2 and 100 characters")
    private String fullName;

    @NotBlank(message = "Phone number is required")
    @Pattern(regexp = "^\\+996\\d{9}$", message = "Phone must be in format +996XXXXXXXXX")
    private String phone;

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotBlank(message = "License number is required")
    private String licenseNumber;

    @NotBlank(message = "License expiry date is required")
    private String licenseExpiry;

    @NotBlank(message = "Vehicle make is required")
    private String vehicleMake;

    @NotBlank(message = "Vehicle model is required")
    private String vehicleModel;

    @NotNull(message = "Vehicle year is required")
    @Min(value = 2000, message = "Vehicle year must be 2000 or later")
    @Max(value = 2030, message = "Vehicle year must be 2030 or earlier")
    private Integer vehicleYear;

    @NotBlank(message = "Vehicle plate is required")
    @Pattern(regexp = "^\\d{2}[A-Z]{3}\\d{2,3}$", message = "Vehicle plate must be in format 01ABC123")
    private String vehiclePlate;

    @NotNull(message = "Car class is required")
    private CarClass carClass;

    private String notes;
}
