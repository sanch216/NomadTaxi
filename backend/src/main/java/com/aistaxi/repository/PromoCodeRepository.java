package com.aistaxi.repository;

import com.aistaxi.model.PromoCode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface PromoCodeRepository extends JpaRepository<PromoCode, Long> {

    Optional<PromoCode> findByCode(String code);

    Page<PromoCode> findByActiveTrue(Pageable pageable);

    @Query("SELECT p FROM PromoCode p WHERE p.active = true " +
           "AND p.validFrom <= :now AND p.validUntil >= :now")
    Page<PromoCode> findActiveAndValid(LocalDateTime now, Pageable pageable);

    @Query("SELECT p FROM PromoCode p WHERE p.code = :code " +
           "AND p.active = true " +
           "AND p.validFrom <= :now AND p.validUntil >= :now")
    Optional<PromoCode> findValidPromoCode(String code, LocalDateTime now);
}
