package com.aistaxi.controller;

import com.aistaxi.dto.*;
import com.aistaxi.model.*;
import com.aistaxi.repository.DriverDetailsRepository;
import com.aistaxi.repository.RideRepository;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.service.AdminActionLogService;
import com.aistaxi.service.DriverApplicationService;
import com.aistaxi.service.DriverManagementService;
import com.aistaxi.service.RideService;
import com.aistaxi.service.TransactionService;
import com.aistaxi.service.PromoCodeService;
import com.aistaxi.service.ReviewService;
import com.aistaxi.service.SupportTicketService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminController {

    private final UserRepository userRepository;
    private final RideRepository rideRepository;
    private final DriverDetailsRepository driverDetailsRepository;
    private final RideService rideService;
    private final AdminActionLogService adminActionLogService;
    private final DriverApplicationService driverApplicationService;
    private final DriverManagementService driverManagementService;
    private final TransactionService transactionService;
    private final PromoCodeService promoCodeService;
    private final ReviewService reviewService;
    private final SupportTicketService supportTicketService;

    private User getAdmin(UserDetails userDetails) {
        return userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("Admin not found"));
    }

    // ==================== DASHBOARD ====================

    @GetMapping("/dashboard/metrics")
    public ResponseEntity<Map<String, Object>> getDashboardMetrics() {
        Map<String, Object> metrics = new HashMap<>();

        // Active rides count
        long activeRides = rideRepository.countByStatusIn(Arrays.asList(RideStatus.ACCEPTED, RideStatus.ARRIVED, RideStatus.IN_PROGRESS));

        // Searching rides count
        long searchingRides = rideRepository.countByStatus(RideStatus.SEARCHING);

        // Online drivers count
        long onlineDrivers = driverDetailsRepository.countByStatusIn(Arrays.asList(DriverStatus.AVAILABLE, DriverStatus.BUSY));

        // Total users
        long totalUsers = userRepository.count();

        // Total drivers
        long totalDrivers = userRepository.countByRole(Role.DRIVER);

        // Total clients
        long totalClients = userRepository.countByRole(Role.CLIENT);

        metrics.put("activeRides", activeRides);
        metrics.put("searchingRides", searchingRides);
        metrics.put("onlineDrivers", onlineDrivers);
        metrics.put("totalUsers", totalUsers);
        metrics.put("totalDrivers", totalDrivers);
        metrics.put("totalClients", totalClients);

        return ResponseEntity.ok(metrics);
    }

    // ==================== USER MANAGEMENT ====================

    @GetMapping("/users")
    public ResponseEntity<org.springframework.data.domain.Page<Map<String, Object>>> getUsers(
            @RequestParam(required = false) Role role,
            @RequestParam(required = false) Boolean enabled,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {

        org.springframework.data.domain.Pageable pageable = org.springframework.data.domain.PageRequest.of(page, size, org.springframework.data.domain.Sort.by("createdAt").descending());
        org.springframework.data.domain.Page<User> usersPage;
        
        if (role != null && enabled != null) {
            usersPage = userRepository.findByRoleAndEnabled(role, enabled, pageable);
        } else if (role != null) {
            usersPage = userRepository.findByRole(role, pageable);
        } else if (enabled != null) {
            usersPage = userRepository.findByEnabled(enabled, pageable);
        } else {
            usersPage = userRepository.findAll(pageable);
        }

        org.springframework.data.domain.Page<Map<String, Object>> result = usersPage.map(this::mapUserToResponse);

        return ResponseEntity.ok(result);
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<Map<String, Object>> getUserById(@PathVariable Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found"));

        return ResponseEntity.ok(mapUserToDetailedResponse(user));
    }

    @PostMapping("/users/{id}/ban")
    public ResponseEntity<Map<String, Object>> banUser(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam(required = false) Integer durationHours,
            @RequestParam String reason) {

        User admin = getAdmin(adminDetails);
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (durationHours != null && durationHours > 0) {
            // Temporary ban
            user.setBlockedUntil(LocalDateTime.now().plusHours(durationHours));
        } else {
            // Permanent ban
            user.setEnabled(false);
        }

        user.setBlockReason(reason);
        userRepository.save(user);

        // Log action
        adminActionLogService.log(admin, ActionType.BAN_USER,
                "User:" + id,
                "Reason: " + reason + ", Duration: " + (durationHours != null ? durationHours + "h" : "permanent"));

        return ResponseEntity.ok(Map.of(
                "message", "User banned successfully",
                "userId", id,
                "blockedUntil", user.getBlockedUntil() != null ? user.getBlockedUntil().toString() : "permanent"
        ));
    }

    @PostMapping("/users/{id}/unban")
    public ResponseEntity<Map<String, Object>> unbanUser(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        User admin = getAdmin(adminDetails);
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found"));

        user.setEnabled(true);
        user.setBlockedUntil(null);
        user.setBlockReason(null);
        userRepository.save(user);

        // Log action
        adminActionLogService.log(admin, ActionType.UNBAN_USER, "User:" + id, null);

        return ResponseEntity.ok(Map.of("message", "User unbanned successfully", "userId", id));
    }

    // ==================== RIDE MANAGEMENT ====================

    @GetMapping("/rides")
    public ResponseEntity<org.springframework.data.domain.Page<RideResponse>> getRides(
            @RequestParam(required = false) RideStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {

        org.springframework.data.domain.Pageable pageable = org.springframework.data.domain.PageRequest.of(page, size, org.springframework.data.domain.Sort.by("createdAt").descending());
        org.springframework.data.domain.Page<Ride> ridesPage;
        
        if (status != null) {
            ridesPage = rideRepository.findByStatus(status, pageable);
        } else {
            ridesPage = rideRepository.findAll(pageable);
        }

        org.springframework.data.domain.Page<RideResponse> result = ridesPage.map(rideService::mapToPublicResponse);

        return ResponseEntity.ok(result);
    }

    @GetMapping("/rides/{id}")
    public ResponseEntity<RideResponse> getRideById(@PathVariable Long id) {
        Ride ride = rideRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        return ResponseEntity.ok(rideService.mapToPublicResponse(ride));
    }

    @PostMapping("/rides/{id}/cancel")
    public ResponseEntity<Map<String, Object>> cancelRide(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam String reason) {

        User admin = getAdmin(adminDetails);
        Ride ride = rideRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Ride not found"));

        if (ride.getStatus() == RideStatus.COMPLETED || ride.getStatus() == RideStatus.CANCELLED) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Cannot cancel completed or already cancelled ride"));
        }

        ride.setStatus(RideStatus.CANCELLED);
        rideRepository.save(ride);

        // Log action
        adminActionLogService.log(admin, ActionType.CANCEL_RIDE,
                "Ride:" + id, "Reason: " + reason);

        return ResponseEntity.ok(Map.of(
                "message", "Ride cancelled successfully",
                "rideId", id
        ));
    }

    // ==================== DRIVER APPLICATIONS ====================

    @GetMapping("/driver-applications")
    public ResponseEntity<Page<DriverApplicationResponse>> getAllApplications(
            @RequestParam(required = false) ApplicationStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        
        Pageable pageable = PageRequest.of(page, size, Sort.by("submittedAt").descending());
        Page<DriverApplicationResponse> result = driverApplicationService.getAllApplications(status, pageable);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/driver-applications/{id}")
    public ResponseEntity<DriverApplicationResponse> getDriverApplication(@PathVariable Long id) {
        DriverApplicationResponse application = driverApplicationService.getApplicationById(id);
        return ResponseEntity.ok(application);
    }

    @PostMapping("/driver-applications/{id}/approve")
    public ResponseEntity<?> approveDriverApplication(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            DriverApplicationResponse response = driverApplicationService.approveApplication(id, admin);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/driver-applications/{id}/reject")
    public ResponseEntity<?> rejectDriverApplication(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam String reason) {

        try {
            User admin = getAdmin(adminDetails);
            DriverApplicationResponse response = driverApplicationService.rejectApplication(id, reason, admin);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/driver-applications/{id}/status")
    public ResponseEntity<?> updateApplicationStatus(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam ApplicationStatus status) {

        try {
            User admin = getAdmin(adminDetails);
            DriverApplicationResponse response = driverApplicationService.updateApplicationStatus(id, status, admin);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // ==================== DRIVER MANAGEMENT ====================

    @PostMapping("/driver-applications/{id}/activate")
    public ResponseEntity<?> activateDriver(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            User driver = driverManagementService.approveAndActivateDriver(id, admin);
            return ResponseEntity.ok(Map.of(
                "message", "Driver activated successfully",
                "driverId", driver.getId(),
                "phone", driver.getPhone()
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/drivers/{id}/terminate")
    public ResponseEntity<?> terminateDriver(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam String reason) {

        try {
            User admin = getAdmin(adminDetails);
            driverManagementService.terminateDriver(id, reason, admin);
            return ResponseEntity.ok(Map.of(
                "message", "Driver terminated successfully",
                "driverId", id
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/drivers/{id}/reactivate")
    public ResponseEntity<?> reactivateDriver(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            driverManagementService.reactivateDriver(id, admin);
            return ResponseEntity.ok(Map.of(
                "message", "Driver reactivated successfully",
                "driverId", id
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/drivers/{id}/verify-documents")
    public ResponseEntity<?> verifyDriverDocuments(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            driverManagementService.verifyDocuments(id, admin);
            return ResponseEntity.ok(Map.of(
                "message", "Documents verified successfully",
                "driverId", id
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/drivers/{id}/reject-documents")
    public ResponseEntity<?> rejectDriverDocuments(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam String reason) {

        try {
            User admin = getAdmin(adminDetails);
            driverManagementService.rejectDocuments(id, reason, admin);
            return ResponseEntity.ok(Map.of(
                "message", "Documents rejected",
                "driverId", id
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // ==================== AUDIT LOGS ====================

    @GetMapping("/audit-logs")
    public ResponseEntity<Page<Map<String, Object>>> getAuditLogs(
            @RequestParam(required = false) Long adminId,
            @RequestParam(required = false) ActionType action,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {

        Pageable pageable = PageRequest.of(page, size, Sort.by("performedAt").descending());
        Page<AdminActionLog> logsPage;

        if (adminId != null) {
            User admin = userRepository.findById(adminId)
                    .orElseThrow(() -> new RuntimeException("Admin not found"));
            logsPage = adminActionLogService.getLogsByAdmin(admin, pageable);
        } else if (action != null) {
            logsPage = adminActionLogService.getLogsByAction(action, pageable);
        } else {
            logsPage = adminActionLogService.getAllLogs(pageable);
        }

        Page<Map<String, Object>> result = logsPage.map(this::mapLogToResponse);
        return ResponseEntity.ok(result);
    }

    // ==================== TRANSACTIONS ====================

    @GetMapping("/transactions")
    public ResponseEntity<Page<TransactionResponse>> getTransactions(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) TransactionType type,
            @RequestParam(required = false) TransactionStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime toDate,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {

        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        Page<Transaction> transactionsPage = transactionService.getAllTransactions(userId, type, status, fromDate, toDate, pageable);

        Page<TransactionResponse> result = transactionsPage.map(this::mapTransactionToResponse);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/transactions/{id}")
    public ResponseEntity<TransactionResponse> getTransaction(@PathVariable Long id) {
        Transaction transaction = transactionService.getTransactionById(id);
        return ResponseEntity.ok(mapTransactionToResponse(transaction));
    }

    @GetMapping("/transactions/user/{userId}")
    public ResponseEntity<List<TransactionResponse>> getUserTransactions(@PathVariable Long userId) {
        List<Transaction> transactions = transactionService.getTransactionsByUser(userId);

        List<TransactionResponse> result = transactions.stream()
                .map(this::mapTransactionToResponse)
                .collect(Collectors.toList());

        return ResponseEntity.ok(result);
    }

    @PostMapping("/transactions/refund")
    public ResponseEntity<?> createRefund(
            @AuthenticationPrincipal UserDetails adminDetails,
            @RequestBody RefundRequest request) {

        try {
            User admin = getAdmin(adminDetails);
            Ride ride = rideRepository.findById(request.getRideId())
                    .orElseThrow(() -> new RuntimeException("Ride not found"));

            Transaction transaction = transactionService.createRefund(
                ride,
                request.getAmount(),
                request.getReason(),
                admin
            );

            return ResponseEntity.ok(mapTransactionToResponse(transaction));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/transactions/adjustment")
    public ResponseEntity<?> createAdjustment(
            @AuthenticationPrincipal UserDetails adminDetails,
            @RequestBody AdjustmentRequest request) {

        try {
            User admin = getAdmin(adminDetails);
            User user = userRepository.findById(request.getUserId())
                    .orElseThrow(() -> new RuntimeException("User not found"));

            Transaction transaction = transactionService.createAdjustment(
                user,
                request.getAmount(),
                request.getReason(),
                admin
            );

            return ResponseEntity.ok(mapTransactionToResponse(transaction));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/transactions/{id}/complete")
    public ResponseEntity<?> completeTransaction(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            Transaction transaction = transactionService.markAsCompleted(id, admin);
            return ResponseEntity.ok(mapTransactionToResponse(transaction));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/transactions/{id}/fail")
    public ResponseEntity<?> failTransaction(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam String reason) {

        try {
            User admin = getAdmin(adminDetails);
            Transaction transaction = transactionService.markAsFailed(id, reason, admin);
            return ResponseEntity.ok(mapTransactionToResponse(transaction));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // ==================== PROMO CODES ====================

    @GetMapping("/promo-codes")
    public ResponseEntity<Page<PromoCodeResponse>> getAllPromoCodes(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        
        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        Page<PromoCode> promoCodesPage = promoCodeService.getAllPromoCodes(pageable);
        Page<PromoCodeResponse> result = promoCodesPage.map(this::mapPromoCodeToResponse);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/promo-codes/active")
    public ResponseEntity<List<PromoCodeResponse>> getActivePromoCodes() {
        List<PromoCode> promoCodes = promoCodeService.getActivePromoCodes();
        List<PromoCodeResponse> result = promoCodes.stream()
                .map(this::mapPromoCodeToResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @GetMapping("/promo-codes/{id}")
    public ResponseEntity<PromoCodeResponse> getPromoCode(@PathVariable Long id) {
        PromoCode promoCode = promoCodeService.getPromoCodeById(id);
        return ResponseEntity.ok(mapPromoCodeToResponse(promoCode));
    }

    @PostMapping("/promo-codes")
    public ResponseEntity<?> createPromoCode(
            @AuthenticationPrincipal UserDetails adminDetails,
            @RequestBody PromoCodeRequest request) {

        try {
            User admin = getAdmin(adminDetails);

            PromoCode promoCode = new PromoCode();
            promoCode.setCode(request.getCode());
            promoCode.setType(request.getType());
            promoCode.setDiscountValue(request.getDiscountValue());
            promoCode.setMaxDiscountAmount(request.getMaxDiscountAmount());
            promoCode.setMinRideAmount(request.getMinRideAmount());
            promoCode.setUsageLimit(request.getUsageLimit());
            promoCode.setPerUserLimit(request.getPerUserLimit());
            promoCode.setValidFrom(request.getValidFrom());
            promoCode.setValidUntil(request.getValidUntil());
            promoCode.setActive(request.getActive() != null ? request.getActive() : true);
            promoCode.setDescription(request.getDescription());

            PromoCode created = promoCodeService.createPromoCode(promoCode, admin);
            return ResponseEntity.ok(mapPromoCodeToResponse(created));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/promo-codes/{id}")
    public ResponseEntity<?> updatePromoCode(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestBody PromoCodeRequest request) {

        try {
            User admin = getAdmin(adminDetails);

            PromoCode updates = new PromoCode();
            updates.setCode(request.getCode());
            updates.setType(request.getType());
            updates.setDiscountValue(request.getDiscountValue());
            updates.setMaxDiscountAmount(request.getMaxDiscountAmount());
            updates.setMinRideAmount(request.getMinRideAmount());
            updates.setUsageLimit(request.getUsageLimit());
            updates.setPerUserLimit(request.getPerUserLimit());
            updates.setValidFrom(request.getValidFrom());
            updates.setValidUntil(request.getValidUntil());
            updates.setActive(request.getActive());
            updates.setDescription(request.getDescription());

            PromoCode updated = promoCodeService.updatePromoCode(id, updates, admin);
            return ResponseEntity.ok(mapPromoCodeToResponse(updated));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/promo-codes/{id}")
    public ResponseEntity<?> deletePromoCode(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            promoCodeService.deletePromoCode(id, admin);
            return ResponseEntity.ok(Map.of("message", "Promo code deleted successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/promo-codes/{id}/deactivate")
    public ResponseEntity<?> deactivatePromoCode(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            promoCodeService.deactivatePromoCode(id, admin);
            PromoCode promoCode = promoCodeService.getPromoCodeById(id);
            return ResponseEntity.ok(mapPromoCodeToResponse(promoCode));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/promo-codes/{id}/usage")
    public ResponseEntity<List<Map<String, Object>>> getPromoCodeUsage(@PathVariable Long id) {
        List<PromoCodeUsage> usages = promoCodeService.getPromoCodeUsageHistory(id);
        List<Map<String, Object>> result = usages.stream()
                .map(this::mapPromoCodeUsageToResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    // ==================== REVIEWS ====================

    @GetMapping("/reviews")
    public ResponseEntity<Page<ReviewResponse>> getAllReviews(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Boolean flagged,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        Page<Review> reviewsPage;

        if (flagged != null && flagged) {
            reviewsPage = reviewService.getFlaggedReviews(pageable);
        } else if (userId != null) {
            reviewsPage = reviewService.getReviewsForUser(userId, false, pageable);
        } else {
            reviewsPage = reviewService.getAllReviews(pageable);
        }

        Page<ReviewResponse> result = reviewsPage.map(this::mapReviewToResponse);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/reviews/{id}")
    public ResponseEntity<ReviewResponse> getReview(@PathVariable Long id) {
        Review review = reviewService.getReviewById(id);
        return ResponseEntity.ok(mapReviewToResponse(review));
    }

    @PostMapping("/reviews/{id}/hide")
    public ResponseEntity<?> hideReview(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam String reason) {

        try {
            User admin = getAdmin(adminDetails);
            Review review = reviewService.hideReview(id, admin, reason);
            return ResponseEntity.ok(mapReviewToResponse(review));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/reviews/{id}/show")
    public ResponseEntity<?> showReview(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            Review review = reviewService.showReview(id, admin);
            return ResponseEntity.ok(mapReviewToResponse(review));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/reviews/{id}/unflag")
    public ResponseEntity<?> unflagReview(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            Review review = reviewService.unflagReview(id, admin);
            return ResponseEntity.ok(mapReviewToResponse(review));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/reviews/{id}")
    public ResponseEntity<?> deleteReview(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            reviewService.deleteReview(id, admin);
            return ResponseEntity.ok(Map.of("message", "Review deleted successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // ==================== SUPPORT TICKETS ====================

    @GetMapping("/tickets")
    public ResponseEntity<Page<TicketResponse>> getAllTickets(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) TicketStatus status,
            @RequestParam(required = false) TicketCategory category,
            @RequestParam(required = false) TicketPriority priority,
            @RequestParam(required = false) Long assignedTo,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime toDate,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {

        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        Page<SupportTicket> ticketsPage = supportTicketService.getAllTickets(
            userId, status, category, priority, assignedTo, fromDate, toDate, pageable
        );

        Page<TicketResponse> result = ticketsPage.map(this::mapTicketToResponse);
        return ResponseEntity.ok(result);
    }

    @GetMapping("/tickets/{id}")
    public ResponseEntity<TicketResponse> getTicket(@PathVariable Long id) {
        SupportTicket ticket = supportTicketService.getTicketById(id);
        return ResponseEntity.ok(mapTicketToResponse(ticket));
    }

    @GetMapping("/tickets/{id}/messages")
    public ResponseEntity<List<TicketMessageResponse>> getTicketMessages(@PathVariable Long id) {
        List<TicketMessage> messages = supportTicketService.getTicketMessages(id, true);
        List<TicketMessageResponse> result = messages.stream()
                .map(this::mapTicketMessageToResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @PostMapping("/tickets/{id}/messages")
    public ResponseEntity<?> addTicketMessage(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestBody Map<String, Object> request) {

        try {
            User admin = getAdmin(adminDetails);
            String message = (String) request.get("message");
            Boolean isInternal = (Boolean) request.getOrDefault("isInternal", false);

            TicketMessage ticketMessage = supportTicketService.addMessage(id, admin, message, isInternal);
            return ResponseEntity.ok(mapTicketMessageToResponse(ticketMessage));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/tickets/{id}/assign")
    public ResponseEntity<?> assignTicket(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam Long assigneeId) {

        try {
            User admin = getAdmin(adminDetails);
            User assignee = userRepository.findById(assigneeId)
                    .orElseThrow(() -> new RuntimeException("Assignee not found"));

            SupportTicket ticket = supportTicketService.assignTicket(id, admin, assignee);
            return ResponseEntity.ok(mapTicketToResponse(ticket));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/tickets/{id}/status")
    public ResponseEntity<?> updateTicketStatus(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam TicketStatus status) {

        try {
            User admin = getAdmin(adminDetails);
            SupportTicket ticket = supportTicketService.updateStatus(id, status, admin);
            return ResponseEntity.ok(mapTicketToResponse(ticket));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/tickets/{id}/priority")
    public ResponseEntity<?> updateTicketPriority(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam TicketPriority priority) {

        try {
            User admin = getAdmin(adminDetails);
            SupportTicket ticket = supportTicketService.updatePriority(id, priority, admin);
            return ResponseEntity.ok(mapTicketToResponse(ticket));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/tickets/{id}/resolve")
    public ResponseEntity<?> resolveTicket(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id,
            @RequestParam String resolutionNotes) {

        try {
            User admin = getAdmin(adminDetails);
            SupportTicket ticket = supportTicketService.resolveTicket(id, admin, resolutionNotes);
            return ResponseEntity.ok(mapTicketToResponse(ticket));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/tickets/{id}/close")
    public ResponseEntity<?> closeTicket(
            @AuthenticationPrincipal UserDetails adminDetails,
            @PathVariable Long id) {

        try {
            User admin = getAdmin(adminDetails);
            SupportTicket ticket = supportTicketService.closeTicket(id, admin);
            return ResponseEntity.ok(mapTicketToResponse(ticket));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/tickets/stats")
    public ResponseEntity<Map<String, Object>> getTicketStats() {
        Long openCount = supportTicketService.getOpenTicketsCount();
        Long inProgressCount = supportTicketService.getInProgressTicketsCount();

        return ResponseEntity.ok(Map.of(
            "openTickets", openCount,
            "inProgressTickets", inProgressCount
        ));
    }

    // ==================== HELPER METHODS ====================

    private Map<String, Object> mapUserToResponse(User user) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", user.getId());
        map.put("phone", user.getPhone());
        map.put("fullName", user.getFullName());
        map.put("role", user.getRole());
        map.put("rating", user.getRating());
        map.put("ratingCount", user.getRatingCount());
        map.put("enabled", user.getEnabled());
        map.put("blockedUntil", user.getBlockedUntil());
        map.put("createdAt", user.getCreatedAt());
        return map;
    }

    private Map<String, Object> mapUserToDetailedResponse(User user) {
        Map<String, Object> map = mapUserToResponse(user);
        map.put("blockReason", user.getBlockReason());
        map.put("terminatedAt", user.getTerminatedAt());
        map.put("terminationReason", user.getTerminationReason());
        map.put("isDocumentsVerified", user.getIsDocumentsVerified());
        return map;
    }

    private Map<String, Object> mapLogToResponse(AdminActionLog log) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", log.getId());
        map.put("adminPhone", log.getAdmin().getPhone());
        map.put("adminName", log.getAdmin().getFullName());
        map.put("action", log.getAction());
        map.put("targetEntity", log.getTargetEntity());
        map.put("details", log.getDetails());
        map.put("performedAt", log.getPerformedAt());
        return map;
    }

    private TransactionResponse mapTransactionToResponse(Transaction transaction) {
        TransactionResponse response = new TransactionResponse();
        response.setId(transaction.getId());
        response.setType(transaction.getType());
        response.setUserId(transaction.getUser().getId());
        response.setUserPhone(transaction.getUser().getPhone());
        response.setUserName(transaction.getUser().getFullName());

        if (transaction.getRide() != null) {
            response.setRideId(transaction.getRide().getId());
        }

        response.setAmount(transaction.getAmount());
        response.setStatus(transaction.getStatus());
        response.setDescription(transaction.getDescription());
        response.setReferenceId(transaction.getReferenceId());
        response.setPaymentMethod(transaction.getPaymentMethod());

        if (transaction.getProcessedBy() != null) {
            response.setProcessedByName(transaction.getProcessedBy().getFullName());
        }

        response.setCreatedAt(transaction.getCreatedAt());
        response.setCompletedAt(transaction.getCompletedAt());
        response.setFailedReason(transaction.getFailedReason());

        return response;
    }

    private PromoCodeResponse mapPromoCodeToResponse(PromoCode promoCode) {
        PromoCodeResponse response = new PromoCodeResponse();
        response.setId(promoCode.getId());
        response.setCode(promoCode.getCode());
        response.setType(promoCode.getType());
        response.setDiscountValue(promoCode.getDiscountValue());
        response.setMaxDiscountAmount(promoCode.getMaxDiscountAmount());
        response.setMinRideAmount(promoCode.getMinRideAmount());
        response.setUsageLimit(promoCode.getUsageLimit());
        response.setUsageCount(promoCode.getUsageCount());
        response.setPerUserLimit(promoCode.getPerUserLimit());
        response.setValidFrom(promoCode.getValidFrom());
        response.setValidUntil(promoCode.getValidUntil());
        response.setActive(promoCode.getActive());
        response.setDescription(promoCode.getDescription());

        if (promoCode.getCreatedBy() != null) {
            response.setCreatedByName(promoCode.getCreatedBy().getFullName());
        }

        response.setCreatedAt(promoCode.getCreatedAt());
        return response;
    }

    private Map<String, Object> mapPromoCodeUsageToResponse(PromoCodeUsage usage) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", usage.getId());
        map.put("promoCode", usage.getPromoCode().getCode());
        map.put("userId", usage.getUser().getId());
        map.put("userName", usage.getUser().getFullName());
        map.put("userPhone", usage.getUser().getPhone());

        if (usage.getRide() != null) {
            map.put("rideId", usage.getRide().getId());
        }

        map.put("discountApplied", usage.getDiscountApplied());
        map.put("usedAt", usage.getUsedAt());
        return map;
    }

    private ReviewResponse mapReviewToResponse(Review review) {
        ReviewResponse response = new ReviewResponse();
        response.setId(review.getId());
        response.setRideId(review.getRide().getId());
        response.setReviewerId(review.getReviewer().getId());
        response.setReviewerName(review.getReviewer().getFullName());
        response.setRevieweeId(review.getReviewee().getId());
        response.setRevieweeName(review.getReviewee().getFullName());
        response.setType(review.getType());
        response.setRating(review.getRating());
        response.setComment(review.getComment());
        response.setIsVisible(review.getIsVisible());
        response.setIsFlagged(review.getIsFlagged());
        response.setFlagReason(review.getFlagReason());

        if (review.getModeratedBy() != null) {
            response.setModeratedByName(review.getModeratedBy().getFullName());
        }

        response.setModeratedAt(review.getModeratedAt());
        response.setCreatedAt(review.getCreatedAt());

        return response;
    }

    private TicketResponse mapTicketToResponse(SupportTicket ticket) {
        TicketResponse response = new TicketResponse();
        response.setId(ticket.getId());
        response.setUserId(ticket.getUser().getId());
        response.setUserName(ticket.getUser().getFullName());
        response.setUserPhone(ticket.getUser().getPhone());

        if (ticket.getRide() != null) {
            response.setRideId(ticket.getRide().getId());
        }

        response.setSubject(ticket.getSubject());
        response.setDescription(ticket.getDescription());
        response.setCategory(ticket.getCategory());
        response.setPriority(ticket.getPriority());
        response.setStatus(ticket.getStatus());

        if (ticket.getAssignedTo() != null) {
            response.setAssignedToId(ticket.getAssignedTo().getId());
            response.setAssignedToName(ticket.getAssignedTo().getFullName());
        }

        response.setAssignedAt(ticket.getAssignedAt());
        response.setResolvedAt(ticket.getResolvedAt());
        response.setClosedAt(ticket.getClosedAt());
        response.setResolutionNotes(ticket.getResolutionNotes());
        response.setCreatedAt(ticket.getCreatedAt());
        response.setUpdatedAt(ticket.getUpdatedAt());

        return response;
    }

    private TicketMessageResponse mapTicketMessageToResponse(TicketMessage message) {
        TicketMessageResponse response = new TicketMessageResponse();
        response.setId(message.getId());
        response.setTicketId(message.getTicket().getId());
        response.setSenderId(message.getSender().getId());
        response.setSenderName(message.getSender().getFullName());
        response.setMessage(message.getMessage());
        response.setIsInternal(message.getIsInternal());
        response.setCreatedAt(message.getCreatedAt());
        return response;
    }
}
