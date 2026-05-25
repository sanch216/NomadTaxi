package com.aistaxi.repository;

import com.aistaxi.model.User;
import com.aistaxi.model.UserBan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserBanRepository extends JpaRepository<UserBan, Long> {

    List<UserBan> findByUserOrderByBannedAtDesc(User user);

    List<UserBan> findByUserAndIsActiveTrueOrderByBannedAtDesc(User user);

    Optional<UserBan> findFirstByUserAndIsActiveTrueOrderByBannedAtDesc(User user);

    List<UserBan> findByBannedByOrderByBannedAtDesc(User admin);
}
