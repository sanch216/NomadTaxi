package com.aistaxi.repository;

import com.aistaxi.model.PromoCodeUsage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PromoCodeUsageRepository extends JpaRepository<PromoCodeUsage, Long> {

    List<PromoCodeUsage> findByPromoCodeId(Long promoCodeId);

    List<PromoCodeUsage> findByUserId(Long userId);

    @Query("SELECT COUNT(u) FROM PromoCodeUsage u WHERE u.promoCode.id = :promoCodeId AND u.user.id = :userId")
    Long countByPromoCodeIdAndUserId(Long promoCodeId, Long userId);

    List<PromoCodeUsage> findByRideId(Long rideId);
}
