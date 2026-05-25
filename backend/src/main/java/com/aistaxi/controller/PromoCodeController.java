package com.aistaxi.controller;

import com.aistaxi.dto.PromoCodeResponse;
import com.aistaxi.dto.ValidatePromoCodeRequest;
import com.aistaxi.model.PromoCode;
import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.service.PromoCodeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/promo-codes")
@RequiredArgsConstructor
public class PromoCodeController {

    private final PromoCodeService promoCodeService;
    private final UserRepository userRepository;

    private User getUser(UserDetails userDetails) {
        return userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    @PostMapping("/validate")
    public ResponseEntity<?> validatePromoCode(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody ValidatePromoCodeRequest request) {

        try {
            User user = getUser(userDetails);
            PromoCode promoCode = promoCodeService.validatePromoCode(
                request.getCode(),
                user,
                request.getRideAmount()
            );

            BigDecimal discount = promoCodeService.calculateDiscount(promoCode, request.getRideAmount());

            return ResponseEntity.ok(Map.of(
                "valid", true,
                "promoCodeId", promoCode.getId(),
                "code", promoCode.getCode(),
                "type", promoCode.getType(),
                "discountAmount", discount,
                "finalAmount", request.getRideAmount().subtract(discount)
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "valid", false,
                "error", e.getMessage()
            ));
        }
    }

    @GetMapping("/{code}")
    public ResponseEntity<?> getPromoCodeByCode(@PathVariable String code) {
        try {
            PromoCode promoCode = promoCodeService.getPromoCodeById(
                promoCodeService.getAllPromoCodes().stream()
                    .filter(p -> p.getCode().equals(code))
                    .findFirst()
                    .orElseThrow(() -> new RuntimeException("Promo code not found"))
                    .getId()
            );

            PromoCodeResponse response = new PromoCodeResponse();
            response.setId(promoCode.getId());
            response.setCode(promoCode.getCode());
            response.setType(promoCode.getType());
            response.setDescription(promoCode.getDescription());
            response.setValidFrom(promoCode.getValidFrom());
            response.setValidUntil(promoCode.getValidUntil());
            response.setMinRideAmount(promoCode.getMinRideAmount());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
