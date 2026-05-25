package com.aistaxi.service;

import com.aistaxi.model.*;
import com.aistaxi.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TransactionService {

    private final TransactionRepository transactionRepository;
    private final AdminActionLogService adminActionLogService;

    @Transactional
    public Transaction createTransaction(
        TransactionType type,
        User user,
        BigDecimal amount,
        String description
    ) {
        Transaction transaction = new Transaction();
        transaction.setType(type);
        transaction.setUser(user);
        transaction.setAmount(amount);
        transaction.setDescription(description);
        transaction.setStatus(TransactionStatus.PENDING);

        return transactionRepository.save(transaction);
    }

    @Transactional
    public Transaction createRidePayment(Ride ride, BigDecimal amount, String paymentMethod) {
        Transaction transaction = new Transaction();
        transaction.setType(TransactionType.RIDE_PAYMENT);
        transaction.setUser(ride.getClient());
        transaction.setRide(ride);
        transaction.setAmount(amount);
        transaction.setPaymentMethod(paymentMethod);
        transaction.setDescription("Payment for ride #" + ride.getId());
        transaction.setStatus(TransactionStatus.COMPLETED);
        transaction.setCompletedAt(LocalDateTime.now());

        return transactionRepository.save(transaction);
    }

    @Transactional
    public Transaction createPayout(User driver, BigDecimal amount, String description, User admin) {
        Transaction transaction = new Transaction();
        transaction.setType(TransactionType.PAYOUT);
        transaction.setUser(driver);
        transaction.setAmount(amount);
        transaction.setDescription(description);
        transaction.setProcessedBy(admin);
        transaction.setStatus(TransactionStatus.COMPLETED);
        transaction.setCompletedAt(LocalDateTime.now());

        transaction = transactionRepository.save(transaction);

        adminActionLogService.log(
            admin,
            ActionType.PROCESS_PAYOUT,
            "Transaction:" + transaction.getId(),
            "Payout to driver " + driver.getId() + ": " + amount
        );

        return transaction;
    }

    @Transactional
    public Transaction createRefund(Ride ride, BigDecimal amount, String reason, User admin) {
        Transaction transaction = new Transaction();
        transaction.setType(TransactionType.REFUND);
        transaction.setUser(ride.getClient());
        transaction.setRide(ride);
        transaction.setAmount(amount);
        transaction.setDescription("Refund for ride #" + ride.getId() + ": " + reason);
        transaction.setProcessedBy(admin);
        transaction.setStatus(TransactionStatus.COMPLETED);
        transaction.setCompletedAt(LocalDateTime.now());

        transaction = transactionRepository.save(transaction);

        adminActionLogService.log(
            admin,
            ActionType.REFUND,
            "Transaction:" + transaction.getId(),
            "Refund for ride " + ride.getId() + ": " + amount + " - " + reason
        );

        return transaction;
    }

    @Transactional
    public Transaction createAdjustment(
        User user,
        BigDecimal amount,
        String reason,
        User admin
    ) {
        Transaction transaction = new Transaction();
        transaction.setType(TransactionType.ADJUSTMENT);
        transaction.setUser(user);
        transaction.setAmount(amount);
        transaction.setDescription("Balance adjustment: " + reason);
        transaction.setProcessedBy(admin);
        transaction.setStatus(TransactionStatus.COMPLETED);
        transaction.setCompletedAt(LocalDateTime.now());

        transaction = transactionRepository.save(transaction);

        adminActionLogService.log(
            admin,
            ActionType.ADJUST_PRICE,
            "Transaction:" + transaction.getId(),
            "Adjustment for user " + user.getId() + ": " + amount + " - " + reason
        );

        return transaction;
    }

    public List<Transaction> getTransactionsByUser(Long userId) {
        return transactionRepository.findByUserId(userId);
    }

    public List<Transaction> getTransactionsByRide(Long rideId) {
        return transactionRepository.findByRideId(rideId);
    }

    public Page<Transaction> getAllTransactions(
        Long userId,
        TransactionType type,
        TransactionStatus status,
        LocalDateTime fromDate,
        LocalDateTime toDate,
        Pageable pageable
    ) {
        return transactionRepository.findAllWithFilters(userId, type, status, fromDate, toDate, pageable);
    }

    public Transaction getTransactionById(Long id) {
        return transactionRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Transaction not found"));
    }

    public Double getTotalEarnings(Long driverId) {
        return transactionRepository.getTotalByUserAndType(driverId, TransactionType.PAYOUT);
    }

    public Double getTotalPayments(Long clientId) {
        return transactionRepository.getTotalByUserAndType(clientId, TransactionType.RIDE_PAYMENT);
    }

    @Transactional
    public Transaction markAsFailed(Long transactionId, String reason, User admin) {
        Transaction transaction = getTransactionById(transactionId);

        if (transaction.getStatus() != TransactionStatus.PENDING) {
            throw new RuntimeException("Can only fail pending transactions");
        }

        transaction.setStatus(TransactionStatus.FAILED);
        transaction.setFailedReason(reason);
        transaction.setProcessedBy(admin);

        return transactionRepository.save(transaction);
    }

    @Transactional
    public Transaction markAsCompleted(Long transactionId, User admin) {
        Transaction transaction = getTransactionById(transactionId);

        if (transaction.getStatus() != TransactionStatus.PENDING) {
            throw new RuntimeException("Can only complete pending transactions");
        }

        transaction.setStatus(TransactionStatus.COMPLETED);
        transaction.setCompletedAt(LocalDateTime.now());
        transaction.setProcessedBy(admin);

        return transactionRepository.save(transaction);
    }
}
