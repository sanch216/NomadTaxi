package com.aistaxi.repository;

import com.aistaxi.model.Transaction;
import com.aistaxi.model.TransactionStatus;
import com.aistaxi.model.TransactionType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    List<Transaction> findByUserId(Long userId);

    List<Transaction> findByRideId(Long rideId);

    List<Transaction> findByType(TransactionType type);

    List<Transaction> findByStatus(TransactionStatus status);

    @Query("SELECT t FROM Transaction t WHERE " +
           "(:userId IS NULL OR t.user.id = :userId) AND " +
           "(:type IS NULL OR t.type = :type) AND " +
           "(:status IS NULL OR t.status = :status) AND " +
           "(:fromDate IS NULL OR t.createdAt >= :fromDate) AND " +
           "(:toDate IS NULL OR t.createdAt <= :toDate)")
    Page<Transaction> findAllWithFilters(
        @Param("userId") Long userId,
        @Param("type") TransactionType type,
        @Param("status") TransactionStatus status,
        @Param("fromDate") LocalDateTime fromDate,
        @Param("toDate") LocalDateTime toDate,
        Pageable pageable
    );

    @Query("SELECT SUM(t.amount) FROM Transaction t WHERE " +
           "t.user.id = :userId AND t.status = 'COMPLETED' AND t.type = :type")
    Double getTotalByUserAndType(@Param("userId") Long userId, @Param("type") TransactionType type);
}
