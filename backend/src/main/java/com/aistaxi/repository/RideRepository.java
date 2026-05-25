package com.aistaxi.repository;

import com.aistaxi.model.CarClass;
import com.aistaxi.model.Ride;
import com.aistaxi.model.RideStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface RideRepository extends JpaRepository<Ride, Long> {
    List<Ride> findAllByClientIdOrDriverIdOrderByCreatedAtDesc(Long clientId, Long driverId);

    long countByStatusAndRequestedCarClass(RideStatus status, CarClass carClass);

    List<Ride> findByStatusAndCreatedAtAfter(RideStatus status, LocalDateTime after);

    long countByStatusIn(List<RideStatus> statuses);
    long countByStatus(RideStatus status);
    
    org.springframework.data.domain.Page<Ride> findByStatus(RideStatus status, org.springframework.data.domain.Pageable pageable);
}
