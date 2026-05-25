package com.aistaxi.service;

import com.aistaxi.dto.DriverFeedItem;
import com.aistaxi.model.*;
import com.aistaxi.repository.DriverDetailsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class RideBroadcastService {

    private final SimpMessagingTemplate messagingTemplate;
    private final DriverDetailsRepository driverDetailsRepository;

    private static final double RATING_THRESHOLD = 0.5;
    private static final int DELAY_SECONDS = 6;

    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(4);

    /**
     * Broadcasts a new ride to all eligible drivers.
     * Drivers with rating 0.5+ points lower than the passenger receive a 6-second
     * delay.
     */
    @Async
    public void broadcastNewRide(Ride ride) {
        User passenger = ride.getClient();
        Double passengerRating = passenger.getRating() != null ? passenger.getRating() : 0.0;

        // Find all available drivers with matching car class
        List<DriverDetails> availableDrivers = driverDetailsRepository.findAll().stream()
                .filter(d -> d.getStatus() == DriverStatus.AVAILABLE)
                .filter(d -> d.getCarClass() == ride.getRequestedCarClass())
                .filter(d -> isWithinRange(d, ride))
                .toList();

        for (DriverDetails driver : availableDrivers) {
            Double driverRating = driver.getUser().getRating() != null ? driver.getUser().getRating() : 0.0;

            DriverFeedItem feedItem = createFeedItem(ride);
            String destination = "/topic/driver/" + driver.getUserId() + "/rides";

            // Check if driver's rating is 0.5+ points lower than passenger's
            if (passengerRating - driverRating >= RATING_THRESHOLD) {
                // Schedule delayed broadcast for lower-rated drivers
                scheduler.schedule(() -> {
                    messagingTemplate.convertAndSend(destination, feedItem);
                    log.info("Delayed broadcast to driver {} (rating: {}) for ride {}",
                            driver.getUserId(), driverRating, ride.getId());
                }, DELAY_SECONDS, TimeUnit.SECONDS);
            } else {
                // Immediate broadcast for higher-rated drivers
                messagingTemplate.convertAndSend(destination, feedItem);
                log.info("Immediate broadcast to driver {} (rating: {}) for ride {}",
                        driver.getUserId(), driverRating, ride.getId());
            }
        }
    }

    private boolean isWithinRange(DriverDetails driver, Ride ride) {
        if (driver.getCurrentLat() == null || driver.getCurrentLon() == null) {
            return false;
        }
        double distance = calculateDistance(
                driver.getCurrentLat(), driver.getCurrentLon(),
                ride.getPickupLat(), ride.getPickupLon());
        return distance <= 5.0; // 5km radius
    }

    private DriverFeedItem createFeedItem(Ride ride) {
        return new DriverFeedItem(
                ride.getId(),
                ride.getPrice(),
                ride.getRequestedCarClass(),
                ride.getPickupAddress(),
                ride.getPickupLat(),
                ride.getPickupLon(),
                ride.getDropoffAddress(),
                ride.getDropoffLat(),
                ride.getDropoffLon());
    }

    private double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Earth's radius in km
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                        * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    /**
     * Broadcasts ride updates to the specific ride topic.
     * Passengers (and drivers) subscribe to /topic/ride/{rideId} to get updates.
     */
    public void broadcastRideUpdate(com.aistaxi.dto.RideResponse rideResponse) {
        String destination = "/topic/ride/" + rideResponse.getId();
        messagingTemplate.convertAndSend(destination, rideResponse);
        log.info("Broadcasted ride update for ride {} to {}", rideResponse.getId(), destination);
    }
}
