package com.aistaxi.service;

import com.aistaxi.model.Ride;
import com.aistaxi.model.RideStatus;
import com.aistaxi.repository.RideRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class HeatmapStartupRunner implements ApplicationRunner {

    private final RideRepository rideRepository;
    private final HeatmapRedisService heatmapRedisService;

    /**
     * On startup, replay the last 24 hours of completed rides into Redis
     * to rebuild the heatmap aggregation state.
     */
    @Override
    public void run(ApplicationArguments args) {
        log.info("Rebuilding heatmap from recent rides...");

        LocalDateTime cutoff = LocalDateTime.now().minusHours(24);
        List<Ride> recentRides = rideRepository.findByStatusAndCreatedAtAfter(
                RideStatus.COMPLETED, cutoff);

        int count = 0;
        for (Ride ride : recentRides) {
            heatmapRedisService.updateCell(
                    ride.getPickupLat(), ride.getPickupLon(), 1.0);
            count++;
        }

        log.info("Heatmap rebuilt with {} rides from the last 24 hours", count);
    }
}
