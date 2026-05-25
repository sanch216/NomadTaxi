package com.aistaxi.controller;

import com.aistaxi.model.DriverStatus;
import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.repository.DriverDetailsRepository;
import com.aistaxi.service.DriverService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import com.aistaxi.model.*;

import java.util.Map;

@RestController
@RequestMapping("/api/driver")
@RequiredArgsConstructor
public class DriverController {

    private final DriverService driverService;
    private final UserRepository userRepository;
    private final DriverDetailsRepository driverDetailsRepository;

    private User getUser(UserDetails userDetails) {
        return userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    @PutMapping("/status")
    public ResponseEntity<?> updateStatus(@AuthenticationPrincipal UserDetails userDetails,
            @RequestParam("status") DriverStatus status) {
        User user = getUser(userDetails);
        // Ensure the user is a driver if necessary, but for now assuming Role check is
        // done via security config or similar,
        // or effectively by the fact that they are calling this endpoint.
        // Ideally we should check if they are a driver.
        // Assuming validation happens in service by presence of DriverDetails.

        DriverStatus newStatus = driverService.updateStatus(user, status);
        return ResponseEntity.ok(Map.of("status", newStatus));
    }

    @PutMapping("/location")
    public ResponseEntity<?> updateLocation(@AuthenticationPrincipal UserDetails userDetails,
            @RequestParam("lat") Double lat,
            @RequestParam("lon") Double lon,
            @RequestParam(value = "status", required = false) DriverStatus status,
            @RequestParam(value = "carClass", required = false) CarClass carClass,
            @RequestParam(value = "carModel", required = false) String carModel,
            @RequestParam(value = "carNumber", required = false) String carNumber) {
        User user = getUser(userDetails);
        DriverDetails details = driverDetailsRepository.findById(user.getId())
                .orElseGet(() -> {
                    DriverDetails d = new DriverDetails();
                    d.setUser(user);
                    d.setUserId(user.getId());
                    return d;
                });

        details.setCurrentLat(lat);
        details.setCurrentLon(lon);
        if (status != null)
            details.setStatus(status);
        if (carClass != null)
            details.setCarClass(carClass);
        if (carModel != null)
            details.setCarModel(carModel);
        if (carNumber != null)
            details.setCarNumber(carNumber);

        driverDetailsRepository.save(details);
        return ResponseEntity.ok(Map.of("message", "Location updated"));
    }

    @GetMapping("/location")
    public ResponseEntity<Double> getRides(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        DriverDetails driverDetails = driverDetailsRepository.findById(user.getId())
                .orElseThrow(() -> new RuntimeException("Driver details not found"));
        return ResponseEntity.ok(driverDetails.getCurrentLat());
    }
}
