package com.aistaxi.service;

import com.aistaxi.dto.WeatherForecastDTO;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@Slf4j
public class WeatherService {

    private static final String API_URL = "https://api.open-meteo.com/v1/forecast?latitude=42.8746&longitude=74.5698"
            + "&hourly=temperature_2m,rain,snowfall&forecast_days=7&timezone=Asia/Bishkek";

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    // Track known forecast dates for driver news
    private final Set<LocalDate> knownForecastDates = new HashSet<>();

    /**
     * Calculates the current weather surge multiplier based on live weather.
     * Snow + temperature can stack. Rain only applies when no snow.
     */
    public BigDecimal getCurrentWeatherSurge() {
        try {
            String response = restTemplate.getForObject(API_URL, String.class);
            JsonNode root = objectMapper.readTree(response);
            JsonNode hourly = root.get("hourly");

            int currentIndex = findCurrentHourIndex(hourly.get("time"));
            if (currentIndex < 0) {
                return BigDecimal.ONE;
            }

            double temperature = hourly.get("temperature_2m").get(currentIndex).asDouble();
            double rain = hourly.get("rain").get(currentIndex).asDouble();
            double snowfall = hourly.get("snowfall").get(currentIndex).asDouble();

            return calculateWeatherSurge(temperature, rain, snowfall);
        } catch (Exception e) {
            log.error("Failed to fetch weather data: {}", e.getMessage());
            return BigDecimal.ONE; // No surge on error
        }
    }

    /**
     * Calculates weather surge from raw weather values.
     * Exported for reuse in forecast calculations.
     */
    public BigDecimal calculateWeatherSurge(double temperature, double rain, double snowfall) {
        BigDecimal surge = BigDecimal.ONE;

        // Temperature surge: only below -1°C
        if (temperature <= -1.0) {
            BigDecimal tempSurge = calculateTemperatureSurge(temperature);
            surge = surge.multiply(tempSurge);
        }

        // Snow and rain are exclusive — snow takes priority
        if (snowfall > 0) {
            BigDecimal snowSurge = calculateSnowSurge(snowfall);
            surge = surge.multiply(snowSurge);
        } else if (rain > 0) {
            BigDecimal rainSurge = calculateRainSurge(rain);
            surge = surge.multiply(rainSurge);
        }

        return surge.setScale(3, RoundingMode.HALF_UP);
    }

    /**
     * Fetches 7-day forecast and returns daily summaries with expected surge.
     * Returns list of new (previously unknown) forecast days.
     */
    public List<WeatherForecastDTO> getDailyForecasts() {
        try {
            String response = restTemplate.getForObject(API_URL, String.class);
            JsonNode root = objectMapper.readTree(response);
            JsonNode hourly = root.get("hourly");

            JsonNode times = hourly.get("time");
            JsonNode temps = hourly.get("temperature_2m");
            JsonNode rains = hourly.get("rain");
            JsonNode snows = hourly.get("snowfall");

            // Group hourly data by date
            Map<LocalDate, List<double[]>> dailyData = new LinkedHashMap<>();

            for (int i = 0; i < times.size(); i++) {
                LocalDate date = LocalDate.parse(times.get(i).asText().substring(0, 10));
                double temp = temps.get(i).asDouble();
                double rain = rains.get(i).asDouble();
                double snow = snows.get(i).asDouble();

                dailyData.computeIfAbsent(date, k -> new ArrayList<>())
                        .add(new double[] { temp, rain, snow });
            }

            List<WeatherForecastDTO> forecasts = new ArrayList<>();
            for (Map.Entry<LocalDate, List<double[]>> entry : dailyData.entrySet()) {
                LocalDate date = entry.getKey();
                List<double[]> hours = entry.getValue();

                double avgTemp = hours.stream().mapToDouble(h -> h[0]).average().orElse(0);
                double totalRain = hours.stream().mapToDouble(h -> h[1]).sum();
                double totalSnow = hours.stream().mapToDouble(h -> h[2]).sum();

                // Calculate expected surge using daily averages
                double avgRainPerHour = totalRain / hours.size();
                double avgSnowPerHour = totalSnow / hours.size();
                BigDecimal expectedSurge = calculateWeatherSurge(avgTemp, avgRainPerHour, avgSnowPerHour);

                String summary = buildSummary(avgTemp, totalRain, totalSnow);

                forecasts.add(new WeatherForecastDTO(
                        date,
                        Math.round(avgTemp * 10.0) / 10.0,
                        Math.round(totalRain * 10.0) / 10.0,
                        Math.round(totalSnow * 10.0) / 10.0,
                        expectedSurge,
                        summary));
            }

            return forecasts;
        } catch (Exception e) {
            log.error("Failed to fetch weather forecast: {}", e.getMessage());
            return Collections.emptyList();
        }
    }

    /**
     * Returns only forecast days that haven't been seen before.
     * Updates the known dates set.
     */
    public List<WeatherForecastDTO> getNewForecastDays() {
        List<WeatherForecastDTO> all = getDailyForecasts();
        List<WeatherForecastDTO> newDays = new ArrayList<>();

        for (WeatherForecastDTO forecast : all) {
            if (!knownForecastDates.contains(forecast.getDate())) {
                newDays.add(forecast);
                knownForecastDates.add(forecast.getDate());
            }
        }

        return newDays;
    }

    // --- Surge calculators ---

    /**
     * Temperature surge: linear scale from -1°C (1.02x) to -20°C (1.10x)
     */
    private BigDecimal calculateTemperatureSurge(double temperature) {
        // Clamp to range [-20, -1]
        double clamped = Math.max(-20.0, Math.min(-1.0, temperature));
        // Linear interpolation: -1 → 1.02, -20 → 1.10
        double factor = 1.02 + ((-1.0 - clamped) / 19.0) * 0.08;
        return BigDecimal.valueOf(factor).setScale(3, RoundingMode.HALF_UP);
    }

    /**
     * Snow surge: 0.1cm → 1.05x, 0.5cm → 1.10x, 1.0cm+ → 1.15x
     */
    private BigDecimal calculateSnowSurge(double snowfallCm) {
        if (snowfallCm >= 1.0) {
            return new BigDecimal("1.150");
        } else if (snowfallCm >= 0.5) {
            // Linear: 0.5 → 1.10, 1.0 → 1.15
            double factor = 1.10 + ((snowfallCm - 0.5) / 0.5) * 0.05;
            return BigDecimal.valueOf(factor).setScale(3, RoundingMode.HALF_UP);
        } else if (snowfallCm > 0) {
            // Linear: 0 → 1.00, 0.5 → 1.10
            double factor = 1.0 + (snowfallCm / 0.5) * 0.10;
            return BigDecimal.valueOf(factor).setScale(3, RoundingMode.HALF_UP);
        }
        return BigDecimal.ONE;
    }

    /**
     * Rain surge: 0.5mm → 1.03x, 2mm → 1.06x, 5mm+ → 1.10x (less than snow)
     */
    private BigDecimal calculateRainSurge(double rainMm) {
        if (rainMm >= 5.0) {
            return new BigDecimal("1.100");
        } else if (rainMm >= 2.0) {
            // Linear: 2.0 → 1.06, 5.0 → 1.10
            double factor = 1.06 + ((rainMm - 2.0) / 3.0) * 0.04;
            return BigDecimal.valueOf(factor).setScale(3, RoundingMode.HALF_UP);
        } else if (rainMm >= 0.5) {
            // Linear: 0.5 → 1.03, 2.0 → 1.06
            double factor = 1.03 + ((rainMm - 0.5) / 1.5) * 0.03;
            return BigDecimal.valueOf(factor).setScale(3, RoundingMode.HALF_UP);
        } else if (rainMm > 0) {
            // Linear: 0 → 1.00, 0.5 → 1.03
            double factor = 1.0 + (rainMm / 0.5) * 0.03;
            return BigDecimal.valueOf(factor).setScale(3, RoundingMode.HALF_UP);
        }
        return BigDecimal.ONE;
    }

    private int findCurrentHourIndex(JsonNode times) {
        LocalDateTime now = LocalDateTime.now();
        String currentHour = now.format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:00"));

        for (int i = 0; i < times.size(); i++) {
            if (times.get(i).asText().equals(currentHour)) {
                return i;
            }
        }
        return -1;
    }

    private String buildSummary(double avgTemp, double totalRain, double totalSnow) {
        StringBuilder sb = new StringBuilder();
        sb.append(String.format("Avg temp: %.1f°C", avgTemp));

        if (totalSnow > 0) {
            sb.append(String.format(", Snow: %.1f cm", totalSnow));
        }
        if (totalRain > 0) {
            sb.append(String.format(", Rain: %.1f mm", totalRain));
        }

        if (avgTemp <= -1)
            sb.append(" ❄️ Cold surge active");
        if (totalSnow > 2)
            sb.append(" 🌨️ Heavy snow surge");
        else if (totalRain > 10)
            sb.append(" 🌧️ Rain surge");

        return sb.toString();
    }
}
