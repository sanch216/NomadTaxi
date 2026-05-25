package com.aistaxi.controller;

import com.aistaxi.dto.AuthResponse;
import com.aistaxi.dto.LoginRequest;
import com.aistaxi.dto.RegisterRequest;
import com.aistaxi.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
@RequestMapping({"/auth", "/api/auth"})
@RequiredArgsConstructor
@Slf4j
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request) {
        log.info("Registration request received for phone: {}, role: {}", request.getPhone(), request.getRole());

        // Block driver registration through public API
        if (request.getRole() == com.aistaxi.model.Role.DRIVER) {
            log.warn("Driver registration blocked for phone: {}", request.getPhone());
            return ResponseEntity.status(403).body(Map.of(
                "error", "Driver registration is not available through this endpoint. " +
                         "Please submit an application through the driver portal."
            ));
        }

        // Only allow CLIENT registration
        if (request.getRole() != com.aistaxi.model.Role.CLIENT) {
            log.warn("Invalid role in registration request: {}", request.getRole());
            return ResponseEntity.status(403).body(Map.of("error", "Invalid role"));
        }

        try {
            AuthResponse response = authService.register(request);
            log.info("Registration successful for phone: {}", request.getPhone());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Registration failed for phone: {}, error: {}", request.getPhone(), e.getMessage());
            return ResponseEntity.status(400).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request) {
        log.info("Login request received for phone: {}", request.getPhone());
        try {
            AuthResponse response = authService.login(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Login failed for phone: {}, error: {}", request.getPhone(), e.getMessage());
            return ResponseEntity.status(401).body(Map.of("error", e.getMessage()));
        }
    }
}
