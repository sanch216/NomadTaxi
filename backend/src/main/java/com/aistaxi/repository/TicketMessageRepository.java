package com.aistaxi.repository;

import com.aistaxi.model.TicketMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TicketMessageRepository extends JpaRepository<TicketMessage, Long> {

    List<TicketMessage> findByTicketId(Long ticketId);

    @Query("SELECT m FROM TicketMessage m WHERE m.ticket.id = :ticketId AND m.isInternal = false ORDER BY m.createdAt ASC")
    List<TicketMessage> findPublicMessagesByTicketId(Long ticketId);

    @Query("SELECT m FROM TicketMessage m WHERE m.ticket.id = :ticketId ORDER BY m.createdAt ASC")
    List<TicketMessage> findAllMessagesByTicketId(Long ticketId);
}
