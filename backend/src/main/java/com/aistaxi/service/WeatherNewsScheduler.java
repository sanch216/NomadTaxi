package com.aistaxi.service;

import com.aistaxi.dto.WeatherForecastDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class WeatherNewsScheduler {

    private final WeatherService weatherService;
    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Runs every hour. Fetches weather forecast and pushes
     * only newly discovered forecast days to drivers via WebSocket.
     */
    @Scheduled(fixedRate = 3600000)
    public void pollWeatherForecast() {
        log.info("Polling weather forecast for driver news...");

        List<WeatherForecastDTO> newDays = weatherService.getNewForecastDays();

        if (!newDays.isEmpty()) {
            messagingTemplate.convertAndSend("/topic/driver/news", newDays);
            log.info("Pushed {} new forecast day(s) to driver news", newDays.size());

            for (WeatherForecastDTO day : newDays) {
                log.info("  {} — surge: {}x — {}", day.getDate(), day.getExpectedSurge(), day.getSummary());
            }
        } else {
            log.info("No new forecast days to push");
        }
    }
}
