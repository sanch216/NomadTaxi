package com.aistaxi.service;

import com.aistaxi.model.ActionType;
import com.aistaxi.model.User;
import com.aistaxi.model.UserBan;
import com.aistaxi.repository.UserBanRepository;
import com.aistaxi.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserBanService {

    private final UserBanRepository userBanRepository;
    private final UserRepository userRepository;
    private final AdminActionLogService adminActionLogService;

    /**
     * Ban a user temporarily or permanently
     * @param user User to ban
     * @param admin Admin issuing the ban
     * @param reason Reason for the ban
     * @param durationHours Duration in hours (null = permanent)
     */
    @Transactional
    public UserBan banUser(User user, User admin, String reason, Integer durationHours) {
        // Deactivate any existing active bans
        List<UserBan> activeBans = userBanRepository.findByUserAndIsActiveTrueOrderByBannedAtDesc(user);
        activeBans.forEach(ban -> ban.setIsActive(false));
        userBanRepository.saveAll(activeBans);

        // Create new ban record
        UserBan ban = new UserBan();
        ban.setUser(user);
        ban.setBannedBy(admin);
        ban.setReason(reason);
        ban.setIsActive(true);

        if (durationHours != null && durationHours > 0) {
            // Temporary ban
            ban.setExpiresAt(LocalDateTime.now().plusHours(durationHours));
            user.setBlockedUntil(ban.getExpiresAt());
        } else {
            // Permanent ban
            user.setEnabled(false);
        }

        user.setBlockReason(reason);
        userRepository.save(user);
        userBanRepository.save(ban);

        // Log action
        adminActionLogService.log(admin, ActionType.BAN_USER,
                "User:" + user.getId(),
                "Reason: " + reason + ", Duration: " + (durationHours != null ? durationHours + "h" : "permanent"));

        log.info("User {} banned by admin {}. Reason: {}, Duration: {}",
                user.getPhone(), admin.getPhone(), reason,
                durationHours != null ? durationHours + "h" : "permanent");

        return ban;
    }

    /**
     * Unban a user
     */
    @Transactional
    public void unbanUser(User user, User admin) {
        // Find active ban
        Optional<UserBan> activeBanOpt = userBanRepository.findFirstByUserAndIsActiveTrueOrderByBannedAtDesc(user);

        if (activeBanOpt.isPresent()) {
            UserBan ban = activeBanOpt.get();
            ban.setIsActive(false);
            ban.setUnbannedAt(LocalDateTime.now());
            ban.setUnbannedBy(admin);
            userBanRepository.save(ban);
        }

        // Clear user ban fields
        user.setEnabled(true);
        user.setBlockedUntil(null);
        user.setBlockReason(null);
        userRepository.save(user);

        // Log action
        adminActionLogService.log(admin, ActionType.UNBAN_USER, "User:" + user.getId(), null);

        log.info("User {} unbanned by admin {}", user.getPhone(), admin.getPhone());
    }

    /**
     * Get all bans for a user
     */
    public List<UserBan> getUserBanHistory(User user) {
        return userBanRepository.findByUserOrderByBannedAtDesc(user);
    }

    /**
     * Get active ban for a user
     */
    public Optional<UserBan> getActiveBan(User user) {
        return userBanRepository.findFirstByUserAndIsActiveTrueOrderByBannedAtDesc(user);
    }

    /**
     * Check if user has an active ban
     */
    public boolean isUserBanned(User user) {
        Optional<UserBan> activeBan = getActiveBan(user);
        if (activeBan.isEmpty()) {
            return false;
        }

        UserBan ban = activeBan.get();

        // Check if temporary ban has expired
        if (ban.getExpiresAt() != null && LocalDateTime.now().isAfter(ban.getExpiresAt())) {
            // Auto-expire the ban
            ban.setIsActive(false);
            userBanRepository.save(ban);

            user.setBlockedUntil(null);
            user.setBlockReason(null);
            userRepository.save(user);

            return false;
        }

        return true;
    }

    /**
     * Get all bans issued by an admin
     */
    public List<UserBan> getBansByAdmin(User admin) {
        return userBanRepository.findByBannedByOrderByBannedAtDesc(admin);
    }
}
