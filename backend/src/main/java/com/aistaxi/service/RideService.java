package com.aistaxi.service;

import com.aistaxi.dto.DriverFeedItem;
import com.aistaxi.dto.RideRequest;
import com.aistaxi.dto.RideResponse;
import com.aistaxi.model.*;
import com.aistaxi.repository.DriverDetailsRepository;
import com.aistaxi.repository.RideRepository;
import com.aistaxi.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RideService {

    private final RideRepository rideRepository;
    private final DriverDetailsRepository driverDetailsRepository;
    private final PricingService pricingService;
    private final RatingService ratingService;
    private final RideBroadcastService rideBroadcastService;
    private final HeatmapRedisService heatmapRedisService;
    private final EarningsService earningsService;
    private final PromoCodeService promoCodeService;

    @Transactional
    public RideResponse createRide(User passenger, RideRequest request) {
        // Validate active rides
        List<RideStatus> activeStatuses = Arrays.asList(RideStatus.SEARCHING, RideStatus.ACCEPTED, RideStatus.ARRIVED,
                RideStatus.IN_PROGRESS);
        boolean hasActiveRide = rideRepository.findAll().stream() // Ideally this should be a DB query
                .anyMatch(
                        r -> r.getClient().getId().equals(passenger.getId()) && activeStatuses.contains(r.getStatus()));

        if (hasActiveRide) {
            throw new RuntimeException("Passenger already has an active ride");
        }

        double distance = calculateDistance(request.getPickupLat(), request.getPickupLon(), request.getDropoffLat(),
                request.getDropoffLon());
        BigDecimal price = pricingService.calculatePrice(distance, request.getRequestedCarClass());

        Ride ride = new Ride();
        ride.setClient(passenger);
        ride.setStatus(RideStatus.SEARCHING);
        ride.setPickupAddress(request.getPickupAddress());
        ride.setPickupLat(request.getPickupLat());
        ride.setPickupLon(request.getPickupLon());
        ride.setDropoffAddress(request.getDropoffAddress());
        ride.setDropoffLat(request.getDropoffLat());
        ride.setDropoffLon(request.getDropoffLon());
        ride.setPrice(price);
        ride.setRequestedCarClass(request.getRequestedCarClass());
        ride.setComment(request.getComment());

        Ride savedRide = rideRepository.save(ride);

        // Broadcast new ride to eligible drivers via WebSocket
        rideBroadcastService.broadcastNewRide(savedRide);

        return mapToResponse(savedRide);
    }

    public List<DriverFeedItem> getDriverFeed(User driver) {
        Long driverId = driver.getId();
        if (driverId == null) {
            throw new RuntimeException("Driver ID is null");
        }
        // Force non-null to satisfy static analyzer if needed, though check above is
        // sufficient
        final long id = driverId;
        DriverDetails details = driverDetailsRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Driver details not found"));

        return rideRepository.findAll().stream() // Should be localized query in production
                .filter(r -> r.getStatus() == RideStatus.SEARCHING)
                .filter(r -> r.getRequestedCarClass() == details.getCarClass())
                .filter(r -> calculateDistance(details.getCurrentLat(), details.getCurrentLon(), r.getPickupLat(),
                        r.getPickupLon()) <= 5.0)
                .map(r -> {
                    return new DriverFeedItem(r.getId(), r.getPrice(),
                            r.getRequestedCarClass(), r.getPickupAddress(), r.getPickupLat(), r.getPickupLon(),
                            r.getDropoffAddress(), r.getDropoffLat(), r.getDropoffLon());
                })
                .collect(Collectors.toList());
    }

    @Transactional
    public RideResponse acceptRide(Long rideId, User driver) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        if (ride.getStatus() != RideStatus.SEARCHING) {
            throw new RuntimeException("Ride already taken or cancelled");
        }

        DriverDetails details = driverDetailsRepository.findById(driver.getId())
                .orElseThrow(() -> new RuntimeException("Driver details not found"));

        if (details.getStatus() != DriverStatus.AVAILABLE) {
            throw new RuntimeException("Driver is busy or offline");
        }

        ride.setDriver(driver);
        ride.setStatus(RideStatus.ACCEPTED);
        rideRepository.save(ride);

        details.setStatus(DriverStatus.BUSY);
        driverDetailsRepository.save(details);

        details.setStatus(DriverStatus.BUSY);
        driverDetailsRepository.save(details);

        RideResponse response = mapToResponse(ride);
        rideBroadcastService.broadcastRideUpdate(response);

        return response;
    }

    @Transactional
    public RideResponse updateStatus(Long rideId, RideStatus newStatus, User driver) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        if (!ride.getDriver().getId().equals(driver.getId())) {
            throw new RuntimeException("Unauthorized: Driver does not own this ride");
        }

        // State Machine validation could go here

        ride.setStatus(newStatus);
        rideRepository.save(ride);

        if (newStatus == RideStatus.COMPLETED) {
            DriverDetails details = driverDetailsRepository.findById(driver.getId())
                    .orElseThrow(() -> new RuntimeException("Driver details not found"));
            details.setStatus(DriverStatus.AVAILABLE);
            details.setCurrentLat(ride.getDropoffLat());
            details.setCurrentLon(ride.getDropoffLon());
            driverDetailsRepository.save(details);

            // Update heatmap with pickup location
            heatmapRedisService.updateCell(ride.getPickupLat(), ride.getPickupLon(), 1.0);

            // Process earnings tracking
            earningsService.processRideCompletion(ride);
        }

        RideResponse response = mapToResponse(ride);
        rideBroadcastService.broadcastRideUpdate(response);

        return response;
    }

    public Optional<RideResponse> getActiveRide(User user) {
        List<RideStatus> activeStatuses = Arrays.asList(RideStatus.SEARCHING, RideStatus.ACCEPTED, RideStatus.ARRIVED,
                RideStatus.IN_PROGRESS);
        // This logic handles both passenger and driver
        return rideRepository.findAll().stream()
                .filter(r -> activeStatuses.contains(r.getStatus()))
                .filter(r -> r.getClient().getId().equals(user.getId())
                        || (r.getDriver() != null && r.getDriver().getId().equals(user.getId())))
                .findFirst()
                .map(this::mapToResponse);
    }

    public List<RideResponse> getRideHistory(User user) {
        return rideRepository.findAllByClientIdOrDriverIdOrderByCreatedAtDesc(user.getId(), user.getId())
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public RideResponse rateDriver(Long rideId, User passenger, Double rating) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        if (ride.getStatus() != RideStatus.COMPLETED) {
            throw new RuntimeException("Can only rate completed rides");
        }

        if (!ride.getClient().getId().equals(passenger.getId())) {
            throw new RuntimeException("Unauthorized: Only the passenger can rate the driver");
        }

        if (ride.getDriver() == null) {
            throw new RuntimeException("No driver assigned to this ride");
        }

        ratingService.updateRating(ride.getDriver(), rating);
        return mapToResponse(ride);
    }

    @Transactional
    public RideResponse ratePassenger(Long rideId, User driver, Double rating) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        if (ride.getStatus() != RideStatus.COMPLETED) {
            throw new RuntimeException("Can only rate completed rides");
        }

        if (ride.getDriver() == null || !ride.getDriver().getId().equals(driver.getId())) {
            throw new RuntimeException("Unauthorized: Only the assigned driver can rate the passenger");
        }

        ratingService.updateRating(ride.getClient(), rating);
        return mapToResponse(ride);
    }

    @Transactional
    public RideResponse cancelRide(Long rideId, User user, String reason) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        // Can only cancel active rides
        List<RideStatus> cancellableStatuses = Arrays.asList(
                RideStatus.SEARCHING,
                RideStatus.ACCEPTED,
                RideStatus.ARRIVED,
                RideStatus.IN_PROGRESS);

        if (!cancellableStatuses.contains(ride.getStatus())) {
            throw new RuntimeException("Ride cannot be cancelled in current status: " + ride.getStatus());
        }

        boolean isPassenger = ride.getClient().getId().equals(user.getId());
        boolean isDriver = ride.getDriver() != null && ride.getDriver().getId().equals(user.getId());

        if (!isPassenger && !isDriver) {
            throw new RuntimeException("Unauthorized: User is not part of this ride");
        }

        // Apply penalty rating (3.0 stars) if ride was accepted
        if (ride.getStatus() != RideStatus.SEARCHING) {
            ratingService.updateRating(user, 3.0);
        }

        // If driver cancels, set their status back to AVAILABLE
        if (isDriver && ride.getDriver() != null) {
            DriverDetails details = driverDetailsRepository.findById(ride.getDriver().getId())
                    .orElseThrow(() -> new RuntimeException("Driver details not found"));
            details.setStatus(DriverStatus.AVAILABLE);
            driverDetailsRepository.save(details);
        }

        ride.setStatus(RideStatus.CANCELLED);
        ride.setCancellationReason(reason);
        ride.setCancelledBy(user);
        rideRepository.save(ride);

        RideResponse response = mapToResponse(ride);
        rideBroadcastService.broadcastRideUpdate(response);

        return response;
    }

    @Transactional
    public RideResponse applyPromoCode(Long rideId, String promoCode, User user) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        if (ride.getStatus() != RideStatus.SEARCHING && ride.getStatus() != RideStatus.ACCEPTED) {
            throw new RuntimeException("Cannot apply promo code to ride in status: " + ride.getStatus());
        }

        if (!ride.getClient().getId().equals(user.getId())) {
            throw new RuntimeException("Unauthorized: Only the client can apply promo code");
        }

        PromoCode validatedPromoCode = promoCodeService.validatePromoCode(promoCode, user, ride.getPrice());
        BigDecimal discountAmount = promoCodeService.calculateDiscount(validatedPromoCode, ride.getPrice());

        ride.setPromoCodeId(validatedPromoCode.getId());
        ride.setDiscountAmount(discountAmount);

        BigDecimal finalPrice = ride.getPrice().subtract(discountAmount);
        if (finalPrice.compareTo(BigDecimal.ZERO) < 0) {
            finalPrice = BigDecimal.ZERO;
        }
        ride.setPrice(finalPrice);

        rideRepository.save(ride);

        promoCodeService.applyPromoCode(validatedPromoCode, user, ride, discountAmount);

        return mapToResponse(ride);
    }

    @Transactional
    public RideResponse processRefund(Long rideId, BigDecimal refundAmount) {
        Ride ride = rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        ride.setRefundAmount(refundAmount);
        ride.setRefundedAt(LocalDateTime.now());
        rideRepository.save(ride);

        return mapToResponse(ride);
    }

    public Ride getRideById(Long rideId) {
        return rideRepository.findById(rideId)
                .orElseThrow(() -> new RuntimeException("Ride not found"));
    }

    public RideResponse mapToPublicResponse(Ride ride) {
        return mapToResponse(ride);
    }

    private RideResponse mapToResponse(Ride ride) {
        RideResponse response = new RideResponse();
        response.setId(ride.getId());
        response.setStatus(ride.getStatus());
        response.setPickupAddress(ride.getPickupAddress());
        response.setPickupLat(ride.getPickupLat());
        response.setPickupLon(ride.getPickupLon());
        response.setDropoffAddress(ride.getDropoffAddress());
        response.setDropoffLat(ride.getDropoffLat());
        response.setDropoffLon(ride.getDropoffLon());
        response.setPrice(ride.getPrice());
        response.setRequestedCarClass(ride.getRequestedCarClass());
        response.setCreatedAt(ride.getCreatedAt());
        response.setSurgeMultiplier(pricingService.calculateSurgeMultiplier(ride.getRequestedCarClass()));
        response.setWeatherSurgeMultiplier(pricingService.getWeatherSurge());
        response.setComment(ride.getComment());
        response.setCancellationReason(ride.getCancellationReason());
        response.setPromoCodeId(ride.getPromoCodeId());
        response.setDiscountAmount(ride.getDiscountAmount());
        response.setRefundAmount(ride.getRefundAmount());
        response.setRefundedAt(ride.getRefundedAt());

        if (ride.getCancelledBy() != null) {
            response.setCancelledByName(ride.getCancelledBy().getFullName());
        }

        if (ride.getDriver() != null) {
            response.setDriverName(ride.getDriver().getFullName());
            response.setDriverPhone(ride.getDriver().getPhone());

            driverDetailsRepository.findById(ride.getDriver().getId()).ifPresent(details -> {
                response.setCarNumber(details.getCarNumber());
                response.setCarModel(details.getCarModel());
                response.setDriverLat(details.getCurrentLat());
                response.setDriverLon(details.getCurrentLon());
            });
        }
        return response;
    }

    // Haversine Implementation
    private double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Radius of the earth

        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                        * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        double distance = R * c;

        return distance;
    }
}
