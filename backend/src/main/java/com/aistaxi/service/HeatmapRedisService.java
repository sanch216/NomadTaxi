package com.aistaxi.service;

import com.aistaxi.util.GeohashUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
@Slf4j
public class HeatmapRedisService {

    private static final double TAU = 21600.0; // 6 hours in seconds
    private static final String DIRTY_SET_KEY = "heatmap:dirty:bishkek";

    private final StringRedisTemplate redis;
    private final DefaultRedisScript<String> updateScript;

    public HeatmapRedisService(StringRedisTemplate redis) {
        this.redis = redis;

        if (redis == null) {
            log.warn("Redis is not available - heatmap features will be disabled");
            this.updateScript = null;
            return;
        }

        // Lua script: atomic decay + add + mark dirty
        // KEYS[1] = cell hash key, KEYS[2] = dirty set key
        // ARGV[1] = nowSeconds, ARGV[2] = weight, ARGV[3] = tau
        // ARGV[4] = centerLat, ARGV[5] = centerLon, ARGV[6] = cellId
        String lua = """
                local key = KEYS[1]
                local dirtyKey = KEYS[2]
                local now = tonumber(ARGV[1])
                local weight = tonumber(ARGV[2])
                local tau = tonumber(ARGV[3])
                local lat = ARGV[4]
                local lon = ARGV[5]
                local cellId = ARGV[6]

                local W = tonumber(redis.call('HGET', key, 'W') or '0')
                local lastTs = tonumber(redis.call('HGET', key, 'lastTs') or '0')

                if lastTs > 0 and W > 0 then
                    local dt = now - lastTs
                    if dt > 0 then
                        W = W * math.exp(-dt / tau)
                    end
                end

                W = W + weight

                redis.call('HSET', key, 'W', tostring(W))
                redis.call('HSET', key, 'lastTs', tostring(now))
                redis.call('HSET', key, 'lat', lat)
                redis.call('HSET', key, 'lon', lon)

                redis.call('SADD', dirtyKey, cellId)

                return tostring(W)
                """;

        this.updateScript = new DefaultRedisScript<>(lua, String.class);
    }

    /**
     * Atomically update a cell: decay existing weight, add new weight, mark dirty.
     */
    public void updateCell(double lat, double lon, double weight) {
        if (redis == null || updateScript == null) {
            log.debug("Redis not available - skipping heatmap update");
            return;
        }

        String cellId = GeohashUtil.encode(lat, lon);
        double[] center = GeohashUtil.decode(cellId);
        String cellKey = "heatmap:cell:" + cellId;
        long nowSeconds = System.currentTimeMillis() / 1000;

        try {
            redis.execute(updateScript,
                    List.of(cellKey, DIRTY_SET_KEY),
                    String.valueOf(nowSeconds),
                    String.valueOf(weight),
                    String.valueOf(TAU),
                    String.valueOf(center[0]),
                    String.valueOf(center[1]),
                    cellId);
            log.debug("Updated heatmap cell {} with weight {}", cellId, weight);
        } catch (Exception e) {
            log.error("Failed to update heatmap cell {}: {}", cellId, e.getMessage());
        }
    }

    /**
     * Get and clear the dirty set — returns cell IDs that changed since last
     * broadcast.
     */
    public Set<String> popDirtyCells() {
        if (redis == null) {
            return Collections.emptySet();
        }

        try {
            Set<String> dirty = redis.opsForSet().members(DIRTY_SET_KEY);
            if (dirty != null && !dirty.isEmpty()) {
                redis.delete(DIRTY_SET_KEY);
            }
            return dirty != null ? dirty : Collections.emptySet();
        } catch (Exception e) {
            log.error("Failed to pop dirty cells: {}", e.getMessage());
            return Collections.emptySet();
        }
    }

    /**
     * Read cell state from Redis. Returns map with W, lastTs, lastSent, lat, lon.
     */
    public Map<String, String> getCellState(String cellId) {
        if (redis == null) {
            return Collections.emptyMap();
        }

        try {
            String cellKey = "heatmap:cell:" + cellId;
            Map<Object, Object> entries = redis.opsForHash().entries(cellKey);
            Map<String, String> result = new HashMap<>();
            entries.forEach((k, v) -> result.put(k.toString(), v.toString()));
            return result;
        } catch (Exception e) {
            log.error("Failed to get cell state for {}: {}", cellId, e.getMessage());
            return Collections.emptyMap();
        }
    }

    /**
     * Update lastSent value after broadcasting.
     */
    public void updateLastSent(String cellId, double value) {
        if (redis == null) {
            return;
        }

        try {
            String cellKey = "heatmap:cell:" + cellId;
            redis.opsForHash().put(cellKey, "lastSent", String.valueOf(value));
        } catch (Exception e) {
            log.error("Failed to update lastSent for {}: {}", cellId, e.getMessage());
        }
    }

    /**
     * Compute the current decayed weight for a cell.
     */
    public double computeCurrentWeight(Map<String, String> state) {
        double W = Double.parseDouble(state.getOrDefault("W", "0"));
        double lastTs = Double.parseDouble(state.getOrDefault("lastTs", "0"));

        if (W <= 0 || lastTs <= 0)
            return 0;

        double nowSeconds = System.currentTimeMillis() / 1000.0;
        double dt = nowSeconds - lastTs;

        if (dt > 0) {
            W = W * Math.exp(-dt / TAU);
        }

        return W;
    }

    /**
     * Get all cell keys in Redis (for live snapshot).
     */
    public Set<String> getAllCellKeys() {
        if (redis == null) {
            return Collections.emptySet();
        }

        try {
            Set<String> keys = redis.keys("heatmap:cell:*");
            return keys != null ? keys : Collections.emptySet();
        } catch (Exception e) {
            log.error("Failed to get all cell keys: {}", e.getMessage());
            return Collections.emptySet();
        }
    }

    /**
     * Remove cells below a weight threshold.
     */
    public void cleanup(double threshold) {
        if (redis == null) {
            return;
        }

        try {
            Set<String> keys = getAllCellKeys();
            int removed = 0;
            for (String key : keys) {
                String cellId = key.replace("heatmap:cell:", "");
                Map<String, String> state = getCellState(cellId);
                double weight = computeCurrentWeight(state);
                if (weight < threshold) {
                    redis.delete(key);
                    removed++;
                }
            }
            if (removed > 0) {
                log.info("Cleaned up {} low-weight heatmap cells", removed);
            }
        } catch (Exception e) {
            log.error("Failed to cleanup heatmap cells: {}", e.getMessage());
        }
    }
}
