package com.aistaxi.controller;

import com.aistaxi.dto.HeatmapCellDTO;
import com.aistaxi.service.HeatmapRedisService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/heatmap")
@RequiredArgsConstructor
public class HeatmapController {

    private final HeatmapRedisService heatmapRedisService;

    /**
     * Returns current live heatmap from Redis (fast, for client re-sync).
     */
    @GetMapping("/live")
    public ResponseEntity<List<HeatmapCellDTO>> getLiveHeatmap() {
        Set<String> keys = heatmapRedisService.getAllCellKeys();
        List<HeatmapCellDTO> cells = new ArrayList<>();

        for (String key : keys) {
            String cellId = key.replace("heatmap:cell:", "");
            Map<String, String> state = heatmapRedisService.getCellState(cellId);
            if (state.isEmpty())
                continue;

            double weight = heatmapRedisService.computeCurrentWeight(state);
            if (weight < 0.01)
                continue; // skip negligible cells

            double lat = Double.parseDouble(state.getOrDefault("lat", "0"));
            double lon = Double.parseDouble(state.getOrDefault("lon", "0"));

            cells.add(new HeatmapCellDTO(cellId, lat, lon, Math.round(weight * 1000.0) / 1000.0));
        }

        return ResponseEntity.ok(cells);
    }

    /**
     * Full authoritative snapshot from Postgres with decay math.
     * Use this for initial load or resync after missed deltas.
     */
    @GetMapping("/snapshot")
    public ResponseEntity<List<HeatmapCellDTO>> getSnapshot() {
        // For now, delegate to the Redis live view.
        // A full Postgres-based query with decay can be added later for strict
        // accuracy.
        return getLiveHeatmap();
    }
}
