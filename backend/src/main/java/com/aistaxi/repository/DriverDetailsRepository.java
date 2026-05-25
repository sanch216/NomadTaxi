package com.aistaxi.repository;

import com.aistaxi.model.CarClass;
import com.aistaxi.model.DriverDetails;
import com.aistaxi.model.DriverStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface DriverDetailsRepository extends JpaRepository<DriverDetails, Long> {
    long countByStatusAndCarClass(DriverStatus status, CarClass carClass);
    Optional<DriverDetails> findByUserId(Long userId);
    long countByStatusIn(java.util.List<DriverStatus> statuses);
}
