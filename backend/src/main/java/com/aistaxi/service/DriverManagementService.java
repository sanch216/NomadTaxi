package com.aistaxi.service;

import com.aistaxi.model.*;
import com.aistaxi.repository.DriverApplicationRepository;
import com.aistaxi.repository.DriverDetailsRepository;
import com.aistaxi.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Random;

@Service
@RequiredArgsConstructor
@Slf4j
public class DriverManagementService {

    private final UserRepository userRepository;
    private final DriverDetailsRepository driverDetailsRepository;
    private final DriverApplicationRepository applicationRepository;
    private final AdminActionLogService adminActionLogService;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public User approveAndActivateDriver(Long applicationId, User admin) {
        DriverApplication application = applicationRepository.findById(applicationId)
                .orElseThrow(() -> new RuntimeException("Application not found"));

        if (application.getStatus() != ApplicationStatus.APPROVED) {
            throw new RuntimeException("Application must be approved first");
        }

        if (application.getCreatedUser() != null) {
            throw new RuntimeException("Driver already activated for this application");
        }

        // Check if phone already exists
        if (userRepository.findByPhone(application.getPhone()).isPresent()) {
            throw new RuntimeException("Phone number already registered");
        }

        // Generate temporary password
        String tempPassword = generateTemporaryPassword();

        // Create User account
        User driver = new User();
        driver.setPhone(application.getPhone());
        driver.setPassword(passwordEncoder.encode(tempPassword));
        driver.setFullName(application.getFullName());
        driver.setRole(Role.DRIVER);
        driver.setEnabled(true);
        driver.setIsDocumentsVerified(false);
        driver = userRepository.save(driver);

        // Create DriverDetails
        DriverDetails details = new DriverDetails();
        details.setUser(driver);
        details.setCarClass(application.getCarClass());
        details.setCarModel(application.getVehicleMake() + " " + application.getVehicleModel());
        details.setCarNumber(application.getVehiclePlate());
        details.setStatus(DriverStatus.OFFLINE);
        details.setCurrentLat(0.0);
        details.setCurrentLon(0.0);
        driverDetailsRepository.save(details);

        // Link application to created user
        application.setCreatedUser(driver);
        applicationRepository.save(application);

        // Log action
        adminActionLogService.log(
            admin,
            ActionType.ACTIVATE_DRIVER,
            "User:" + driver.getId(),
            "Activated driver from application #" + applicationId + ", temp password: " + tempPassword
        );

        // TODO: Send SMS with credentials
        log.info("=== DRIVER ACTIVATED ===");
        log.info("Phone: {}", driver.getPhone());
        log.info("Temporary Password: {}", tempPassword);
        log.info("========================");

        return driver;
    }

    @Transactional
    public void terminateDriver(Long driverId, String reason, User admin) {
        User driver = userRepository.findById(driverId)
                .orElseThrow(() -> new RuntimeException("Driver not found"));

        if (driver.getRole() != Role.DRIVER) {
            throw new RuntimeException("User is not a driver");
        }

        // Disable account
        driver.setEnabled(false);
        driver.setTerminatedAt(LocalDateTime.now());
        driver.setTerminationReason(reason);
        userRepository.save(driver);

        // Set driver status to offline
        DriverDetails details = driverDetailsRepository.findByUserId(driverId)
                .orElse(null);
        if (details != null) {
            details.setStatus(DriverStatus.OFFLINE);
            driverDetailsRepository.save(details);
        }

        // Log action
        adminActionLogService.log(
            admin,
            ActionType.TERMINATE_DRIVER,
            "User:" + driverId,
            "Reason: " + reason
        );

        // TODO: Send SMS notification
        log.info("Driver terminated: {} - Reason: {}", driver.getPhone(), reason);
    }

    @Transactional
    public void reactivateDriver(Long driverId, User admin) {
        User driver = userRepository.findById(driverId)
                .orElseThrow(() -> new RuntimeException("Driver not found"));

        if (driver.getRole() != Role.DRIVER) {
            throw new RuntimeException("User is not a driver");
        }

        if (driver.getTerminatedAt() == null) {
            throw new RuntimeException("Driver is not terminated");
        }

        // Re-enable account
        driver.setEnabled(true);
        driver.setTerminatedAt(null);
        driver.setTerminationReason(null);
        userRepository.save(driver);

        // Log action
        adminActionLogService.log(
            admin,
            ActionType.REACTIVATE_DRIVER,
            "User:" + driverId,
            "Driver reactivated"
        );

        // TODO: Send SMS notification
        log.info("Driver reactivated: {}", driver.getPhone());
    }

    @Transactional
    public void verifyDocuments(Long driverId, User admin) {
        User driver = userRepository.findById(driverId)
                .orElseThrow(() -> new RuntimeException("Driver not found"));

        if (driver.getRole() != Role.DRIVER) {
            throw new RuntimeException("User is not a driver");
        }

        driver.setIsDocumentsVerified(true);
        userRepository.save(driver);

        // Log action
        adminActionLogService.log(
            admin,
            ActionType.VERIFY_DOCUMENT,
            "User:" + driverId,
            "Documents verified"
        );

        // TODO: Send SMS notification
        log.info("Documents verified for driver: {}", driver.getPhone());
    }

    @Transactional
    public void rejectDocuments(Long driverId, String reason, User admin) {
        User driver = userRepository.findById(driverId)
                .orElseThrow(() -> new RuntimeException("Driver not found"));

        if (driver.getRole() != Role.DRIVER) {
            throw new RuntimeException("User is not a driver");
        }

        driver.setIsDocumentsVerified(false);
        userRepository.save(driver);

        // Log action
        adminActionLogService.log(
            admin,
            ActionType.REJECT_DOCUMENT,
            "User:" + driverId,
            "Documents rejected: " + reason
        );

        // TODO: Send SMS notification
        log.info("Documents rejected for driver: {} - Reason: {}", driver.getPhone(), reason);
    }

    private String generateTemporaryPassword() {
        String chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        Random random = new Random();
        StringBuilder password = new StringBuilder();
        for (int i = 0; i < 8; i++) {
            password.append(chars.charAt(random.nextInt(chars.length())));
        }
        return password.toString();
    }
}
