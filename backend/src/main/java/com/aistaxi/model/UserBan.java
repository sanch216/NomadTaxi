package com.aistaxi.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "user_bans")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserBan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(optional = false)
    @JoinColumn(name = "banned_by", nullable = false)
    private User bannedBy; // Admin who issued the ban

    @Column(name = "banned_at", nullable = false, updatable = false)
    private LocalDateTime bannedAt;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt; // null = permanent ban

    @Column(name = "reason", nullable = false, length = 500)
    private String reason;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    @Column(name = "unbanned_at")
    private LocalDateTime unbannedAt;

    @ManyToOne
    @JoinColumn(name = "unbanned_by")
    private User unbannedBy; // Admin who lifted the ban

    @PrePersist
    protected void onCreate() {
        if (bannedAt == null) {
            bannedAt = LocalDateTime.now();
        }
    }
}
