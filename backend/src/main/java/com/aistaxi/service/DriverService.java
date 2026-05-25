package com.aistaxi.service;

import com.aistaxi.model.DriverDetails;
import com.aistaxi.model.DriverStatus;
import com.aistaxi.model.User;
import com.aistaxi.repository.DriverDetailsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DriverService {

    private final DriverDetailsRepository driverDetailsRepository;

    @Transactional
    public DriverStatus updateStatus(User driver, DriverStatus newStatus) {
        DriverDetails details = driverDetailsRepository.findById(driver.getId())
                .orElseThrow(() -> new RuntimeException("Driver details not found"));

        details.setStatus(newStatus);
        driverDetailsRepository.save(details);
        return details.getStatus();
    }
}
