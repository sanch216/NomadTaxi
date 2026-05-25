package com.aistaxi.controller;

import com.aistaxi.dto.DriverApplicationRequest;
import com.aistaxi.dto.DriverApplicationResponse;
import com.aistaxi.service.DriverApplicationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/driver-applications")
@RequiredArgsConstructor
public class DriverApplicationController {

    private final DriverApplicationService applicationService;

    @PostMapping
    public ResponseEntity<?> submitApplication(@Valid @RequestBody DriverApplicationRequest request) {
        try {
            DriverApplicationResponse response = applicationService.submitApplication(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getApplication(@PathVariable Long id) {
        try {
            DriverApplicationResponse response = applicationService.getApplicationById(id);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }
}
