package com.aistaxi.controller;

import com.aistaxi.dto.TicketMessageResponse;
import com.aistaxi.dto.TicketRequest;
import com.aistaxi.dto.TicketResponse;
import com.aistaxi.model.SupportTicket;
import com.aistaxi.model.TicketMessage;
import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.service.SupportTicketService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/tickets")
@RequiredArgsConstructor
public class SupportTicketController {

    private final SupportTicketService ticketService;
    private final UserRepository userRepository;

    private User getUser(UserDetails userDetails) {
        return userRepository.findByPhone(userDetails.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }

    @PostMapping
    public ResponseEntity<?> createTicket(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody TicketRequest request) {

        try {
            User user = getUser(userDetails);
            SupportTicket ticket = ticketService.createTicket(
                user,
                request.getSubject(),
                request.getDescription(),
                request.getCategory(),
                request.getRideId()
            );

            return ResponseEntity.ok(mapToResponse(ticket));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/my")
    public ResponseEntity<List<TicketResponse>> getMyTickets(@AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        List<SupportTicket> tickets = ticketService.getUserTickets(user.getId());
        List<TicketResponse> result = tickets.stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getTicket(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id) {

        try {
            User user = getUser(userDetails);
            SupportTicket ticket = ticketService.getTicketById(id);

            if (!ticket.getUser().getId().equals(user.getId())) {
                return ResponseEntity.status(403).body(Map.of("error", "Access denied"));
            }

            return ResponseEntity.ok(mapToResponse(ticket));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{id}/messages")
    public ResponseEntity<?> addMessage(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {

        try {
            User user = getUser(userDetails);
            SupportTicket ticket = ticketService.getTicketById(id);

            if (!ticket.getUser().getId().equals(user.getId())) {
                return ResponseEntity.status(403).body(Map.of("error", "Access denied"));
            }

            String message = request.get("message");
            TicketMessage ticketMessage = ticketService.addMessage(id, user, message, false);

            return ResponseEntity.ok(mapMessageToResponse(ticketMessage));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{id}/messages")
    public ResponseEntity<?> getTicketMessages(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id) {

        try {
            User user = getUser(userDetails);
            SupportTicket ticket = ticketService.getTicketById(id);

            if (!ticket.getUser().getId().equals(user.getId())) {
                return ResponseEntity.status(403).body(Map.of("error", "Access denied"));
            }

            List<TicketMessage> messages = ticketService.getTicketMessages(id, false);
            List<TicketMessageResponse> result = messages.stream()
                    .map(this::mapMessageToResponse)
                    .collect(Collectors.toList());

            return ResponseEntity.ok(result);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    private TicketResponse mapToResponse(SupportTicket ticket) {
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

    private TicketMessageResponse mapMessageToResponse(TicketMessage message) {
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
