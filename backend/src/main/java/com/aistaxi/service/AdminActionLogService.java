package com.aistaxi.service;

import com.aistaxi.model.ActionType;
import com.aistaxi.model.AdminActionLog;
import com.aistaxi.model.User;
import com.aistaxi.repository.AdminActionLogRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class AdminActionLogService {

    private final AdminActionLogRepository adminActionLogRepository;

    /**
     * Log an admin action
     * @param admin User who performed the action
     * @param action Type of action
     * @param targetEntity Target entity in format "EntityType:id" (e.g., "User:123", "Ride:456")
     * @param details Additional details (can be JSON or plain text)
     */
    @Transactional
    public void log(User admin, ActionType action, String targetEntity, String details) {
        AdminActionLog logEntry = new AdminActionLog();
        logEntry.setAdmin(admin);
        logEntry.setAction(action);
        logEntry.setTargetEntity(targetEntity);
        logEntry.setDetails(details);

        adminActionLogRepository.save(logEntry);

        log.info("Admin action logged: {} by {} on {} - {}",
            action, admin.getPhone(), targetEntity, details);
    }

    /**
     * Get all logs for a specific admin
     */
    public Page<AdminActionLog> getLogsByAdmin(User admin, Pageable pageable) {
        return adminActionLogRepository.findByAdmin(admin, pageable);
    }

    /**
     * Get all logs for a specific action type
     */
    public Page<AdminActionLog> getLogsByAction(ActionType action, Pageable pageable) {
        return adminActionLogRepository.findByAction(action, pageable);
    }

    /**
     * Get all logs for a specific target entity
     */
    public Page<AdminActionLog> getLogsByTarget(String targetEntity, Pageable pageable) {
        return adminActionLogRepository.findByTargetEntity(targetEntity, pageable);
    }

    /**
     * Get logs within a date range
     */
    public Page<AdminActionLog> getLogsByDateRange(LocalDateTime start, LocalDateTime end, Pageable pageable) {
        return adminActionLogRepository.findByPerformedAtBetween(start, end, pageable);
    }

    /**
     * Get all logs
     */
    public Page<AdminActionLog> getAllLogs(Pageable pageable) {
        return adminActionLogRepository.findAll(pageable);
    }
}
