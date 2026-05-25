package com.aistaxi.repository;

import com.aistaxi.model.ApplicationStatus;
import com.aistaxi.model.DriverApplication;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface DriverApplicationRepository extends JpaRepository<DriverApplication, Long> {

    Page<DriverApplication> findByStatus(ApplicationStatus status, Pageable pageable);

    Optional<DriverApplication> findByPhone(String phone);

    Optional<DriverApplication> findByVehiclePlate(String vehiclePlate);

    @Query("SELECT a FROM DriverApplication a WHERE " +
           "(:status IS NULL OR a.status = :status)")
    Page<DriverApplication> findAllWithFilters(@Param("status") ApplicationStatus status, Pageable pageable);
}
