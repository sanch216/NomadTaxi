package com.aistaxi.service;

import com.aistaxi.dto.EarningsSummaryDto;
import com.aistaxi.model.DriverEarning;
import com.aistaxi.model.Ride;
import com.aistaxi.repository.DriverEarningRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class EarningsService {

    private final DriverEarningRepository driverEarningRepository;

    @Transactional
    public void processRideCompletion(Ride ride) {
        BigDecimal totalAmount = ride.getPrice();
        BigDecimal driverShare = totalAmount.multiply(new BigDecimal("0.80"));
        BigDecimal platformFee = totalAmount.subtract(driverShare);

        DriverEarning earning = new DriverEarning();
        earning.setDriver(ride.getDriver());
        earning.setRide(ride);
        earning.setTotalAmount(totalAmount);
        earning.setDriverShare(driverShare);
        earning.setPlatformFee(platformFee);
        earning.setCreatedAt(LocalDateTime.now());

        driverEarningRepository.save(earning);

        log.info("Payment processed for Ride ID: {}, Driver earned: {}", ride.getId(), driverShare);
    }

    public EarningsSummaryDto getDriverStats(Long driverId) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime startOfWeek = LocalDate.now().minusDays(LocalDate.now().getDayOfWeek().getValue() - 1)
                .atStartOfDay();

        BigDecimal todayEarnings = driverEarningRepository.sumDriverShareByDriverIdAndCreatedAtBetween(driverId,
                startOfDay, now);
        BigDecimal weekEarnings = driverEarningRepository.sumDriverShareByDriverIdAndCreatedAtBetween(driverId,
                startOfWeek, now);
        Integer totalRides = driverEarningRepository.countByDriverId(driverId);

        return new EarningsSummaryDto(
                todayEarnings != null ? todayEarnings : BigDecimal.ZERO,
                weekEarnings != null ? weekEarnings : BigDecimal.ZERO,
                totalRides != null ? totalRides : 0);
    }
}
