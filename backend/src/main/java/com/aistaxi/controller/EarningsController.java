package com.aistaxi.controller;

import com.aistaxi.dto.EarningsSummaryDto;
import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.service.EarningsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/driver/earnings")
@RequiredArgsConstructor
public class EarningsController {

    private final EarningsService earningsService;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<EarningsSummaryDto> getEarnings(@AuthenticationPrincipal UserDetails userDetails) {
        User user = userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));

        return ResponseEntity.ok(earningsService.getDriverStats(user.getId()));
    }
}
