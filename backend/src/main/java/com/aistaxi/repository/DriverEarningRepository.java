package com.aistaxi.repository;

import com.aistaxi.model.DriverEarning;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Repository
public interface DriverEarningRepository extends JpaRepository<DriverEarning, Long> {

    @Query("SELECT SUM(e.driverShare) FROM DriverEarning e WHERE e.driver.id = :driverId AND e.createdAt BETWEEN :start AND :end")
    BigDecimal sumDriverShareByDriverIdAndCreatedAtBetween(@Param("driverId") Long driverId,
            @Param("start") LocalDateTime start,
            @Param("end") LocalDateTime end);

    @Query("SELECT COUNT(e) FROM DriverEarning e WHERE e.driver.id = :driverId")
    Integer countByDriverId(@Param("driverId") Long driverId);
}
