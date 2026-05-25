package com.aistaxi.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class LoginRequest {
    @NotBlank(message = "Phone number is required")
    @Pattern(regexp = "^\\+996\\d{9}$", message = "Phone must be in format +996XXXXXXXXX")
    private String phone;

    @NotBlank(message = "Password is required")
    private String password;
}
