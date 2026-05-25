package com.aistaxi.service;

import com.aistaxi.model.*;
import com.aistaxi.repository.PromoCodeRepository;
import com.aistaxi.repository.PromoCodeUsageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PromoCodeService {

    private final PromoCodeRepository promoCodeRepository;
    private final PromoCodeUsageRepository promoCodeUsageRepository;
    private final AdminActionLogService adminActionLogService;

    @Transactional
    public PromoCode createPromoCode(PromoCode promoCode, User admin) {
        if (promoCodeRepository.findByCode(promoCode.getCode()).isPresent()) {
            throw new RuntimeException("Promo code already exists: " + promoCode.getCode());
        }

        promoCode.setCreatedBy(admin);
        PromoCode saved = promoCodeRepository.save(promoCode);

        adminActionLogService.log(
            admin,
            ActionType.CREATE_PROMO,
            "PromoCode:" + saved.getId(),
            "Created promo code: " + saved.getCode()
        );

        return saved;
    }

    @Transactional
    public PromoCode updatePromoCode(Long id, PromoCode updates, User admin) {
        PromoCode existing = promoCodeRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Promo code not found"));

        if (updates.getCode() != null && !updates.getCode().equals(existing.getCode())) {
            if (promoCodeRepository.findByCode(updates.getCode()).isPresent()) {
                throw new RuntimeException("Promo code already exists: " + updates.getCode());
            }
            existing.setCode(updates.getCode());
        }

        if (updates.getType() != null) existing.setType(updates.getType());
        if (updates.getDiscountValue() != null) existing.setDiscountValue(updates.getDiscountValue());
        if (updates.getMaxDiscountAmount() != null) existing.setMaxDiscountAmount(updates.getMaxDiscountAmount());
        if (updates.getMinRideAmount() != null) existing.setMinRideAmount(updates.getMinRideAmount());
        if (updates.getUsageLimit() != null) existing.setUsageLimit(updates.getUsageLimit());
        if (updates.getPerUserLimit() != null) existing.setPerUserLimit(updates.getPerUserLimit());
        if (updates.getValidFrom() != null) existing.setValidFrom(updates.getValidFrom());
        if (updates.getValidUntil() != null) existing.setValidUntil(updates.getValidUntil());
        if (updates.getActive() != null) existing.setActive(updates.getActive());
        if (updates.getDescription() != null) existing.setDescription(updates.getDescription());

        PromoCode saved = promoCodeRepository.save(existing);

        adminActionLogService.log(
            admin,
            ActionType.UPDATE_PROMO,
            "PromoCode:" + saved.getId(),
            "Updated promo code: " + saved.getCode()
        );

        return saved;
    }

    @Transactional
    public void deletePromoCode(Long id, User admin) {
        PromoCode promoCode = promoCodeRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Promo code not found"));

        promoCodeRepository.delete(promoCode);

        adminActionLogService.log(
            admin,
            ActionType.DELETE_PROMO,
            "PromoCode:" + id,
            "Deleted promo code: " + promoCode.getCode()
        );
    }

    @Transactional
    public void deactivatePromoCode(Long id, User admin) {
        PromoCode promoCode = promoCodeRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Promo code not found"));

        promoCode.setActive(false);
        promoCodeRepository.save(promoCode);

        adminActionLogService.log(
            admin,
            ActionType.UPDATE_PROMO,
            "PromoCode:" + id,
            "Deactivated promo code: " + promoCode.getCode()
        );
    }

    public PromoCode getPromoCodeById(Long id) {
        return promoCodeRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Promo code not found"));
    }

    public Page<PromoCode> getAllPromoCodes(Pageable pageable) {
        return promoCodeRepository.findAll(pageable);
    }

    public List<PromoCode> getAllPromoCodes() {
        return promoCodeRepository.findAll();
    }

    public Page<PromoCode> getActivePromoCodes(Pageable pageable) {
        return promoCodeRepository.findActiveAndValid(LocalDateTime.now(), pageable);
    }

    public List<PromoCode> getActivePromoCodes() {
        return promoCodeRepository.findActiveAndValid(LocalDateTime.now(), Pageable.unpaged()).getContent();
    }

    public PromoCode validatePromoCode(String code, User user, BigDecimal rideAmount) {
        PromoCode promoCode = promoCodeRepository.findValidPromoCode(code, LocalDateTime.now())
            .orElseThrow(() -> new RuntimeException("Invalid or expired promo code"));

        if (promoCode.getMinRideAmount() != null && rideAmount.compareTo(promoCode.getMinRideAmount()) < 0) {
            throw new RuntimeException("Ride amount is below minimum required: " + promoCode.getMinRideAmount());
        }

        if (promoCode.getUsageLimit() != null && promoCode.getUsageCount() >= promoCode.getUsageLimit()) {
            throw new RuntimeException("Promo code usage limit reached");
        }

        if (promoCode.getPerUserLimit() != null) {
            Long userUsageCount = promoCodeUsageRepository.countByPromoCodeIdAndUserId(promoCode.getId(), user.getId());
            if (userUsageCount >= promoCode.getPerUserLimit()) {
                throw new RuntimeException("You have reached the usage limit for this promo code");
            }
        }

        return promoCode;
    }

    public BigDecimal calculateDiscount(PromoCode promoCode, BigDecimal rideAmount) {
        BigDecimal discount;

        switch (promoCode.getType()) {
            case PERCENTAGE:
                discount = rideAmount.multiply(promoCode.getDiscountValue())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
                if (promoCode.getMaxDiscountAmount() != null && discount.compareTo(promoCode.getMaxDiscountAmount()) > 0) {
                    discount = promoCode.getMaxDiscountAmount();
                }
                break;

            case FIXED_AMOUNT:
                discount = promoCode.getDiscountValue();
                if (discount.compareTo(rideAmount) > 0) {
                    discount = rideAmount;
                }
                break;

            case FREE_RIDE:
                discount = rideAmount;
                break;

            default:
                throw new RuntimeException("Unknown promo code type: " + promoCode.getType());
        }

        return discount;
    }

    @Transactional
    public PromoCodeUsage applyPromoCode(PromoCode promoCode, User user, Ride ride, BigDecimal discountApplied) {
        promoCode.setUsageCount(promoCode.getUsageCount() + 1);
        promoCodeRepository.save(promoCode);

        PromoCodeUsage usage = new PromoCodeUsage();
        usage.setPromoCode(promoCode);
        usage.setUser(user);
        usage.setRide(ride);
        usage.setDiscountApplied(discountApplied);

        return promoCodeUsageRepository.save(usage);
    }

    public List<PromoCodeUsage> getPromoCodeUsageHistory(Long promoCodeId) {
        return promoCodeUsageRepository.findByPromoCodeId(promoCodeId);
    }

    public List<PromoCodeUsage> getUserPromoCodeUsage(Long userId) {
        return promoCodeUsageRepository.findByUserId(userId);
    }
}
