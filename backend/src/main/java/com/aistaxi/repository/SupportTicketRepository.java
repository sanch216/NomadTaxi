package com.aistaxi.repository;

import com.aistaxi.model.SupportTicket;
import com.aistaxi.model.TicketStatus;
import com.aistaxi.model.TicketCategory;
import com.aistaxi.model.TicketPriority;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface SupportTicketRepository extends JpaRepository<SupportTicket, Long> {

    List<SupportTicket> findByUserId(Long userId);

    List<SupportTicket> findByStatus(TicketStatus status);

    List<SupportTicket> findByCategory(TicketCategory category);

    List<SupportTicket> findByPriority(TicketPriority priority);

    List<SupportTicket> findByAssignedToId(Long adminId);

    List<SupportTicket> findByRideId(Long rideId);

    @Query("SELECT t FROM SupportTicket t WHERE " +
           "(:userId IS NULL OR t.user.id = :userId) AND " +
           "(:status IS NULL OR t.status = :status) AND " +
           "(:category IS NULL OR t.category = :category) AND " +
           "(:priority IS NULL OR t.priority = :priority) AND " +
           "(:assignedTo IS NULL OR t.assignedTo.id = :assignedTo) AND " +
           "(:fromDate IS NULL OR t.createdAt >= :fromDate) AND " +
           "(:toDate IS NULL OR t.createdAt <= :toDate)")
    Page<SupportTicket> findAllWithFilters(
        @Param("userId") Long userId,
        @Param("status") TicketStatus status,
        @Param("category") TicketCategory category,
        @Param("priority") TicketPriority priority,
        @Param("assignedTo") Long assignedTo,
        @Param("fromDate") LocalDateTime fromDate,
        @Param("toDate") LocalDateTime toDate,
        Pageable pageable
    );

    @Query("SELECT COUNT(t) FROM SupportTicket t WHERE t.status = :status")
    Long countByStatus(@Param("status") TicketStatus status);
}
