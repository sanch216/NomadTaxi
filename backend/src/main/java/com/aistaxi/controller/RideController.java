package com.aistaxi.controller;

import com.aistaxi.dto.DriverFeedItem;
import com.aistaxi.dto.EstimateRequest;
import com.aistaxi.dto.EstimateResponse;
import com.aistaxi.dto.RideRequest;
import com.aistaxi.dto.RideResponse;
import com.aistaxi.dto.WeatherForecastDTO;
import com.aistaxi.model.CarClass;
import com.aistaxi.model.Ride;
import com.aistaxi.model.RideStatus;
import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.service.PricingService;
import com.aistaxi.service.RideService;
import com.aistaxi.service.WeatherService;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/rides")
@RequiredArgsConstructor
public class RideController {

    private final RideService rideService;
    private final UserRepository userRepository;
    private final PricingService pricingService;
    private final WeatherService weatherService;

    private User getUser(UserDetails userDetails) {
        return userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    /**
     * POST /api/rides/estimate
     * Returns price estimates for all car classes given pickup/dropoff coordinates.
     */
    @PostMapping("/estimate")
    public ResponseEntity<List<EstimateResponse>> getEstimates(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody EstimateRequest request) {

        double distanceKm = haversineKm(
                request.getPickupLat(), request.getPickupLon(),
                request.getDropoffLat(), request.getDropoffLon());

        List<EstimateResponse> estimates = new ArrayList<>();
        for (CarClass carClass : CarClass.values()) {
            BigDecimal price = pricingService.calculatePrice(distanceKm, carClass);
            // Mock arrival time: 3-8 min depending on class
            int arrival = switch (carClass) {
                case ECONOMY -> 5;
                case COMFORT -> 7;
                case BUSINESS -> 3;
            };
            estimates.add(new EstimateResponse(carClass.name(), price.doubleValue(), arrival));
        }
        return ResponseEntity.ok(estimates);
    }

    /** Haversine distance between two lat/lon points in kilometres. */
    private double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        double R = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                        * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    @GetMapping("/surge")
    public ResponseEntity<Map<String, Object>> getSurge(@RequestParam("carClass") CarClass carClass) {
        BigDecimal demandSurge = pricingService.calculateSurgeMultiplier(carClass);
        BigDecimal weatherSurge = pricingService.getWeatherSurge();
        return ResponseEntity.ok(Map.of(
                "carClass", carClass,
                "demandSurge", demandSurge,
                "weatherSurge", weatherSurge));
    }

    @GetMapping("/weather-forecast")
    public ResponseEntity<List<WeatherForecastDTO>> getWeatherForecast() {
        return ResponseEntity.ok(weatherService.getDailyForecasts());
    }

    @PostMapping
    public ResponseEntity<RideResponse> createRide(@AuthenticationPrincipal UserDetails userDetails,
            @RequestBody RideRequest request) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.createRide(user, request));
    }

    @GetMapping("/feed")
    public ResponseEntity<List<DriverFeedItem>> getDriverFeed(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.getDriverFeed(user));
    }

    @PostMapping("/{id}/accept")
    public ResponseEntity<RideResponse> acceptRide(@AuthenticationPrincipal UserDetails userDetails,
            @PathVariable("id") Long id) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.acceptRide(id, user));
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<RideResponse> updateStatus(@AuthenticationPrincipal UserDetails userDetails,
            @PathVariable("id") Long id,
            @RequestParam("status") RideStatus status) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.updateStatus(id, status, user));
    }

    @GetMapping("/{id}")
    public ResponseEntity<RideResponse> getRideById(@AuthenticationPrincipal UserDetails userDetails,
            @PathVariable("id") Long id) {
        User user = getUser(userDetails);
        Ride ride = rideService.getRideById(id);
        // Verify user is part of this ride
        if (!ride.getClient().getId().equals(user.getId())
                && (ride.getDriver() == null || !ride.getDriver().getId().equals(user.getId()))) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        return ResponseEntity.ok(rideService.mapToPublicResponse(ride));
    }

    @GetMapping("/current")
    public ResponseEntity<?> getActiveRide(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        return rideService.getActiveRide(user)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.noContent().build());
    }

    @GetMapping("/history")
    public ResponseEntity<List<RideResponse>> getRideHistory(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.getRideHistory(user));
    }

    @PostMapping("/{id}/rate-driver")
    public ResponseEntity<RideResponse> rateDriver(@AuthenticationPrincipal UserDetails userDetails,
            @PathVariable("id") Long id,
            @RequestParam("rating") Double rating) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.rateDriver(id, user, rating));
    }

    @PostMapping("/{id}/rate-passenger")
    public ResponseEntity<RideResponse> ratePassenger(@AuthenticationPrincipal UserDetails userDetails,
            @PathVariable("id") Long id,
            @RequestParam("rating") Double rating) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.ratePassenger(id, user, rating));
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<RideResponse> cancelRide(@AuthenticationPrincipal UserDetails userDetails,
            @PathVariable("id") Long id,
            @RequestParam(value = "reason", required = false) String reason) {
        User user = getUser(userDetails);
        return ResponseEntity.ok(rideService.cancelRide(id, user, reason));
    }

    @PostMapping("/{id}/apply-promo")
    public ResponseEntity<?> applyPromoCode(@AuthenticationPrincipal UserDetails userDetails,
            @PathVariable("id") Long id,
            @RequestParam("code") String promoCode) {
        try {
            User user = getUser(userDetails);
            RideResponse response = rideService.applyPromoCode(id, promoCode, user);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @ExceptionHandler(OptimisticLockingFailureException.class)
    public ResponseEntity<?> handleOptimisticLockingFailure(OptimisticLockingFailureException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("error", "Ride was updated by another user. Please refresh."));
    }
}
