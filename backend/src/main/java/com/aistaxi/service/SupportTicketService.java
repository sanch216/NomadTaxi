package com.aistaxi.service;

import com.aistaxi.model.*;
import com.aistaxi.repository.SupportTicketRepository;
import com.aistaxi.repository.TicketMessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SupportTicketService {

    private final SupportTicketRepository ticketRepository;
    private final TicketMessageRepository messageRepository;
    private final AdminActionLogService adminActionLogService;

    @Transactional
    public SupportTicket createTicket(
        User user,
        String subject,
        String description,
        TicketCategory category,
        Long rideId
    ) {
        SupportTicket ticket = new SupportTicket();
        ticket.setUser(user);
        ticket.setSubject(subject);
        ticket.setDescription(description);
        ticket.setCategory(category);
        ticket.setStatus(TicketStatus.OPEN);
        ticket.setPriority(TicketPriority.MEDIUM);

        if (rideId != null) {
            Ride ride = new Ride();
            ride.setId(rideId);
            ticket.setRide(ride);
        }

        return ticketRepository.save(ticket);
    }

    @Transactional
    public TicketMessage addMessage(Long ticketId, User sender, String message, Boolean isInternal) {
        SupportTicket ticket = getTicketById(ticketId);

        TicketMessage ticketMessage = new TicketMessage();
        ticketMessage.setTicket(ticket);
        ticketMessage.setSender(sender);
        ticketMessage.setMessage(message);
        ticketMessage.setIsInternal(isInternal != null ? isInternal : false);

        ticket.setUpdatedAt(LocalDateTime.now());
        ticketRepository.save(ticket);

        return messageRepository.save(ticketMessage);
    }

    @Transactional
    public SupportTicket assignTicket(Long ticketId, User admin, User assignee) {
        SupportTicket ticket = getTicketById(ticketId);

        ticket.setAssignedTo(assignee);
        ticket.setAssignedAt(LocalDateTime.now());
        ticket.setStatus(TicketStatus.IN_PROGRESS);

        SupportTicket saved = ticketRepository.save(ticket);

        adminActionLogService.log(
            admin,
            ActionType.ASSIGN_TICKET,
            "Ticket:" + ticketId,
            "Assigned ticket to " + assignee.getFullName()
        );

        return saved;
    }

    @Transactional
    public SupportTicket updateStatus(Long ticketId, TicketStatus newStatus, User admin) {
        SupportTicket ticket = getTicketById(ticketId);

        ticket.setStatus(newStatus);

        if (newStatus == TicketStatus.RESOLVED) {
            ticket.setResolvedAt(LocalDateTime.now());
        } else if (newStatus == TicketStatus.CLOSED) {
            ticket.setClosedAt(LocalDateTime.now());
        }

        SupportTicket saved = ticketRepository.save(ticket);

        adminActionLogService.log(
            admin,
            ActionType.UPDATE_TICKET_STATUS,
            "Ticket:" + ticketId,
            "Updated status to " + newStatus
        );

        return saved;
    }

    @Transactional
    public SupportTicket updatePriority(Long ticketId, TicketPriority newPriority, User admin) {
        SupportTicket ticket = getTicketById(ticketId);

        ticket.setPriority(newPriority);

        SupportTicket saved = ticketRepository.save(ticket);

        adminActionLogService.log(
            admin,
            ActionType.UPDATE_TICKET_PRIORITY,
            "Ticket:" + ticketId,
            "Updated priority to " + newPriority
        );

        return saved;
    }

    @Transactional
    public SupportTicket resolveTicket(Long ticketId, User admin, String resolutionNotes) {
        SupportTicket ticket = getTicketById(ticketId);

        ticket.setStatus(TicketStatus.RESOLVED);
        ticket.setResolvedAt(LocalDateTime.now());
        ticket.setResolutionNotes(resolutionNotes);

        SupportTicket saved = ticketRepository.save(ticket);

        adminActionLogService.log(
            admin,
            ActionType.RESOLVE_TICKET,
            "Ticket:" + ticketId,
            "Resolved ticket: " + resolutionNotes
        );

        return saved;
    }

    @Transactional
    public SupportTicket closeTicket(Long ticketId, User admin) {
        SupportTicket ticket = getTicketById(ticketId);

        ticket.setStatus(TicketStatus.CLOSED);
        ticket.setClosedAt(LocalDateTime.now());

        SupportTicket saved = ticketRepository.save(ticket);

        adminActionLogService.log(
            admin,
            ActionType.CLOSE_TICKET,
            "Ticket:" + ticketId,
            "Closed ticket"
        );

        return saved;
    }

    public SupportTicket getTicketById(Long id) {
        return ticketRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Ticket not found"));
    }

    public List<SupportTicket> getUserTickets(Long userId) {
        return ticketRepository.findByUserId(userId);
    }

    public List<SupportTicket> getTicketsByStatus(TicketStatus status) {
        return ticketRepository.findByStatus(status);
    }

    public List<SupportTicket> getAssignedTickets(Long adminId) {
        return ticketRepository.findByAssignedToId(adminId);
    }

    public Page<SupportTicket> getAllTickets(
        Long userId,
        TicketStatus status,
        TicketCategory category,
        TicketPriority priority,
        Long assignedTo,
        LocalDateTime fromDate,
        LocalDateTime toDate,
        Pageable pageable
    ) {
        return ticketRepository.findAllWithFilters(
            userId, status, category, priority, assignedTo, fromDate, toDate, pageable
        );
    }

    public List<TicketMessage> getTicketMessages(Long ticketId, boolean includeInternal) {
        if (includeInternal) {
            return messageRepository.findAllMessagesByTicketId(ticketId);
        }
        return messageRepository.findPublicMessagesByTicketId(ticketId);
    }

    public Long getOpenTicketsCount() {
        return ticketRepository.countByStatus(TicketStatus.OPEN);
    }

    public Long getInProgressTicketsCount() {
        return ticketRepository.countByStatus(TicketStatus.IN_PROGRESS);
    }
}
