package com.aistaxi.service;

import com.aistaxi.model.CarClass;
import com.aistaxi.model.DriverStatus;
import com.aistaxi.model.RideStatus;
import com.aistaxi.repository.DriverDetailsRepository;
import com.aistaxi.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Service
@RequiredArgsConstructor
public class PricingService {

    private final DriverDetailsRepository driverDetailsRepository;
    private final RideRepository rideRepository;
    private final WeatherService weatherService;

    // ── Tariffs per class (Kyrgyz Som, competitive with Yandex/Maxim Bishkek) ──

    // Economy: Yandex ~7.6 сом/км, Maxim ~10-17 сом/км, min ~100-140 сом
    private static final BigDecimal ECONOMY_BASE = new BigDecimal("70.00");
    private static final BigDecimal ECONOMY_PER_KM = new BigDecimal("10.00");
    private static final BigDecimal ECONOMY_PER_MIN = new BigDecimal("3.50");
    private static final BigDecimal ECONOMY_MIN_FARE = new BigDecimal("100.00");

    // Comfort: Yandex ~10.5 сом/км
    private static final BigDecimal COMFORT_BASE = new BigDecimal("100.00");
    private static final BigDecimal COMFORT_PER_KM = new BigDecimal("13.00");
    private static final BigDecimal COMFORT_PER_MIN = new BigDecimal("5.00");
    private static final BigDecimal COMFORT_MIN_FARE = new BigDecimal("150.00");

    // Business: Yandex ~16 сом/км
    private static final BigDecimal BUSINESS_BASE = new BigDecimal("150.00");
    private static final BigDecimal BUSINESS_PER_KM = new BigDecimal("18.00");
    private static final BigDecimal BUSINESS_PER_MIN = new BigDecimal("8.00");
    private static final BigDecimal BUSINESS_MIN_FARE = new BigDecimal("250.00");

    private static final BigDecimal MAX_SURGE = new BigDecimal("2.0");
    /** Average city speed for time estimate (km/h). */
    private static final double AVG_SPEED_KMH = 25.0;

    /**
     * Price formula:
     * estimatedMinutes = distance / avgSpeed * 60
     * rawPrice = baseFare + (distance * perKm) + (minutes * perMin)
     * weatherAdjusted = rawPrice * weatherSurge
     * finalPrice = max(weatherAdjusted * demandSurge, minFare)
     */
    public BigDecimal calculatePrice(double distanceKm, CarClass carClass) {
        BigDecimal weatherSurge = weatherService.getCurrentWeatherSurge();
        return calculatePriceInternal(distanceKm, carClass, weatherSurge);
    }

    private BigDecimal calculatePriceInternal(double distanceKm, CarClass carClass, BigDecimal weatherSurge) {
        BigDecimal base = getBase(carClass);
        BigDecimal perKm = getPerKm(carClass);
        BigDecimal perMin = getPerMin(carClass);
        BigDecimal minFare = getMinFare(carClass);

        // Estimate trip duration based on average city speed.
        double estimatedMinutes = (distanceKm / AVG_SPEED_KMH) * 60.0;

        BigDecimal distanceCost = perKm.multiply(BigDecimal.valueOf(distanceKm));
        BigDecimal timeCost = perMin.multiply(BigDecimal.valueOf(estimatedMinutes));
        BigDecimal rawPrice = base.add(distanceCost).add(timeCost);

        BigDecimal demandSurge = calculateSurgeMultiplier(carClass);

        BigDecimal finalPrice = rawPrice
                .multiply(weatherSurge)
                .multiply(demandSurge)
                .setScale(0, RoundingMode.HALF_UP);

        finalPrice = finalPrice.max(minFare);

        // Bound ECONOMY by COMFORT price
        if (carClass == CarClass.ECONOMY) {
            BigDecimal comfortPrice = calculatePriceInternal(distanceKm, CarClass.COMFORT, weatherSurge);
            BigDecimal maxEconomyPrice = comfortPrice.subtract(BigDecimal.ONE).max(minFare);
            if (finalPrice.compareTo(maxEconomyPrice) > 0) {
                finalPrice = maxEconomyPrice;
            }
        }
        // Bound COMFORT by BUSINESS price
        else if (carClass == CarClass.COMFORT) {
            BigDecimal businessPrice = calculatePriceInternal(distanceKm, CarClass.BUSINESS, weatherSurge);
            BigDecimal maxComfortPrice = businessPrice.subtract(BigDecimal.ONE).max(minFare);
            if (finalPrice.compareTo(maxComfortPrice) > 0) {
                finalPrice = maxComfortPrice;
            }
        }

        return finalPrice;
    }

    /**
     * Calculates the demand surge multiplier based on supply/demand.
     * Formula: max(1.0, min(demand / supply, MAX_SURGE))
     */
    public BigDecimal calculateSurgeMultiplier(CarClass carClass) {
        long demand = rideRepository.countByStatusAndRequestedCarClass(RideStatus.SEARCHING, carClass);
        long supply = driverDetailsRepository.countByStatusAndCarClass(DriverStatus.AVAILABLE, carClass);

        if (supply == 0) {
            return demand > 0 ? MAX_SURGE : BigDecimal.ONE;
        }

        BigDecimal ratio = BigDecimal.valueOf(demand)
                .divide(BigDecimal.valueOf(supply), 2, RoundingMode.HALF_UP);

        if (ratio.compareTo(BigDecimal.ONE) < 0) {
            return BigDecimal.ONE;
        }
        if (ratio.compareTo(MAX_SURGE) > 0) {
            return MAX_SURGE;
        }

        return ratio.setScale(1, RoundingMode.HALF_UP);
    }

    public BigDecimal getWeatherSurge() {
        return weatherService.getCurrentWeatherSurge();
    }

    // ── Per-class tariff lookups ──────────────────────────────────────────

    private BigDecimal getBase(CarClass c) {
        return switch (c) {
            case ECONOMY -> ECONOMY_BASE;
            case COMFORT -> COMFORT_BASE;
            case BUSINESS -> BUSINESS_BASE;
        };
    }

    private BigDecimal getPerKm(CarClass c) {
        return switch (c) {
            case ECONOMY -> ECONOMY_PER_KM;
            case COMFORT -> COMFORT_PER_KM;
            case BUSINESS -> BUSINESS_PER_KM;
        };
    }

    private BigDecimal getPerMin(CarClass c) {
        return switch (c) {
            case ECONOMY -> ECONOMY_PER_MIN;
            case COMFORT -> COMFORT_PER_MIN;
            case BUSINESS -> BUSINESS_PER_MIN;
        };
    }

    private BigDecimal getMinFare(CarClass c) {
        return switch (c) {
            case ECONOMY -> ECONOMY_MIN_FARE;
            case COMFORT -> COMFORT_MIN_FARE;
            case BUSINESS -> BUSINESS_MIN_FARE;
        };
    }
}
