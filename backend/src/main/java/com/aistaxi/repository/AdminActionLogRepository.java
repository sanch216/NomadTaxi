package com.aistaxi.repository;

import com.aistaxi.model.AdminActionLog;
import com.aistaxi.model.ActionType;
import com.aistaxi.model.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface AdminActionLogRepository extends JpaRepository<AdminActionLog, Long> {

    Page<AdminActionLog> findByAdmin(User admin, Pageable pageable);

    Page<AdminActionLog> findByAction(ActionType action, Pageable pageable);

    Page<AdminActionLog> findByTargetEntity(String targetEntity, Pageable pageable);

    Page<AdminActionLog> findByPerformedAtBetween(
        LocalDateTime start,
        LocalDateTime end,
        Pageable pageable
    );
}
