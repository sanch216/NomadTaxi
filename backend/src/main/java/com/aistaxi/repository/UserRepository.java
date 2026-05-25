package com.aistaxi.repository;

import com.aistaxi.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByPhone(String phone);
    
    long countByRole(com.aistaxi.model.Role role);
    
    org.springframework.data.domain.Page<User> findByRole(com.aistaxi.model.Role role, org.springframework.data.domain.Pageable pageable);
    org.springframework.data.domain.Page<User> findByEnabled(Boolean enabled, org.springframework.data.domain.Pageable pageable);
    org.springframework.data.domain.Page<User> findByRoleAndEnabled(com.aistaxi.model.Role role, Boolean enabled, org.springframework.data.domain.Pageable pageable);
}
