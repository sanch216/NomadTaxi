package com.aistaxi.service;

import com.aistaxi.dto.HeatmapCellDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.*;

@Component
@RequiredArgsConstructor
@Slf4j
public class HeatmapBroadcaster {

    private static final double EPSILON = 0.05; // minimum change to push

    private final HeatmapRedisService heatmapRedisService;
    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Runs every 3 seconds. Reads dirty cells, computes current decayed weights,
     * filters by epsilon threshold, and pushes deltas to WebSocket subscribers.
     */
    @Scheduled(fixedRate = 3000)
    public void broadcastDirtyChanges() {
        Set<String> dirtyCells = heatmapRedisService.popDirtyCells();
        if (dirtyCells.isEmpty())
            return;

        List<HeatmapCellDTO> deltas = new ArrayList<>();

        for (String cellId : dirtyCells) {
            Map<String, String> state = heatmapRedisService.getCellState(cellId);
            if (state.isEmpty())
                continue;

            double currentWeight = heatmapRedisService.computeCurrentWeight(state);
            double lastSent = Double.parseDouble(state.getOrDefault("lastSent", "0"));

            // Only push if change exceeds epsilon
            if (Math.abs(currentWeight - lastSent) >= EPSILON) {
                double lat = Double.parseDouble(state.getOrDefault("lat", "0"));
                double lon = Double.parseDouble(state.getOrDefault("lon", "0"));

                deltas.add(new HeatmapCellDTO(cellId, lat, lon, Math.round(currentWeight * 1000.0) / 1000.0));
                heatmapRedisService.updateLastSent(cellId, currentWeight);
            }
        }

        if (!deltas.isEmpty()) {
            messagingTemplate.convertAndSend("/topic/heatmap/bishkek", deltas);
            log.debug("Pushed {} heatmap cell deltas", deltas.size());
        }
    }
}
