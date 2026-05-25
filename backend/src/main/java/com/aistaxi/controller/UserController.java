package com.aistaxi.controller;

import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import com.aistaxi.model.Role;
import com.aistaxi.model.DriverDetails;
import com.aistaxi.repository.DriverDetailsRepository;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserRepository userRepository;
    private final DriverDetailsRepository driverDetailsRepository;

    @GetMapping("/me")
    public ResponseEntity<?> getProfile(@AuthenticationPrincipal UserDetails userDetails) {
        User user = userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));

        return ResponseEntity.ok(buildUserResponse(user));
    }

    @PutMapping("/me")
    public ResponseEntity<?> updateProfile(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, String> body) {
        User user = userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (body.containsKey("fullName")) {
            user.setFullName(body.get("fullName"));
        }
        userRepository.save(user);

        return ResponseEntity.ok(buildUserResponse(user));
    }

    private Map<String, Object> buildUserResponse(User user) {
        Map<String, Object> response = new HashMap<>();
        response.put("id", user.getId());
        response.put("fullName", user.getFullName() != null ? user.getFullName() : "");
        response.put("phone", user.getPhone());
        response.put("rating", user.getRating() != null ? user.getRating() : 5.0);
        response.put("ratingCount", user.getRatingCount() != null ? user.getRatingCount() : 0);
        response.put("role", user.getRole());

        if (user.getRole() == Role.DRIVER) {
            driverDetailsRepository.findById(user.getId()).ifPresent(details -> {
                response.put("carModel", details.getCarModel());
                response.put("carNumber", details.getCarNumber());
            });
        }
        return response;
    }
}
