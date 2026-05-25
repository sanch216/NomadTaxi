package com.aistaxi.service;

import com.aistaxi.dto.DriverApplicationRequest;
import com.aistaxi.dto.DriverApplicationResponse;
import com.aistaxi.model.*;
import com.aistaxi.repository.DriverApplicationRepository;
import com.aistaxi.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DriverApplicationService {

    private final DriverApplicationRepository applicationRepository;
    private final UserRepository userRepository;
    private final AdminActionLogService adminActionLogService;

    @Transactional
    public DriverApplicationResponse submitApplication(DriverApplicationRequest request) {
        // Check if phone already exists
        if (userRepository.findByPhone(request.getPhone()).isPresent()) {
            throw new RuntimeException("Phone number already registered");
        }

        // Check if application already exists for this phone
        if (applicationRepository.findByPhone(request.getPhone()).isPresent()) {
            throw new RuntimeException("Application already submitted for this phone number");
        }

        // Check if vehicle plate already exists
        if (request.getVehiclePlate() != null &&
            applicationRepository.findByVehiclePlate(request.getVehiclePlate()).isPresent()) {
            throw new RuntimeException("Vehicle plate already registered");
        }

        DriverApplication application = new DriverApplication();
        application.setFullName(request.getFullName());
        application.setPhone(request.getPhone());
        application.setEmail(request.getEmail());
        application.setLicenseNumber(request.getLicenseNumber());
        application.setLicenseExpiry(request.getLicenseExpiry());
        application.setVehicleMake(request.getVehicleMake());
        application.setVehicleModel(request.getVehicleModel());
        application.setVehicleYear(request.getVehicleYear());
        application.setVehiclePlate(request.getVehiclePlate());
        application.setCarClass(request.getCarClass());
        application.setNotes(request.getNotes());
        application.setStatus(ApplicationStatus.PENDING);

        application = applicationRepository.save(application);

        return mapToResponse(application);
    }

    public Page<DriverApplicationResponse> getAllApplications(ApplicationStatus status, Pageable pageable) {
        Page<DriverApplication> applications;
        if (status != null) {
            applications = applicationRepository.findByStatus(status, pageable);
        } else {
            applications = applicationRepository.findAllWithFilters(null, pageable);
        }
        return applications.map(this::mapToResponse);
    }

    public DriverApplicationResponse getApplicationById(Long id) {
        DriverApplication application = applicationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Application not found"));
        return mapToResponse(application);
    }

    @Transactional
    public DriverApplicationResponse approveApplication(Long id, User admin) {
        DriverApplication application = applicationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Application not found"));

        if (application.getStatus() != ApplicationStatus.PENDING &&
            application.getStatus() != ApplicationStatus.UNDER_REVIEW) {
            throw new RuntimeException("Application cannot be approved in current status: " + application.getStatus());
        }

        application.setStatus(ApplicationStatus.APPROVED);
        application.setReviewedAt(LocalDateTime.now());
        application.setReviewedBy(admin);

        application = applicationRepository.save(application);

        adminActionLogService.log(
            admin,
            ActionType.APPROVE_DRIVER_APPLICATION,
            "DriverApplication:" + id,
            "Approved application for " + application.getFullName()
        );

        return mapToResponse(application);
    }

    @Transactional
    public DriverApplicationResponse rejectApplication(Long id, String reason, User admin) {
        DriverApplication application = applicationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Application not found"));

        if (application.getStatus() != ApplicationStatus.PENDING &&
            application.getStatus() != ApplicationStatus.UNDER_REVIEW) {
            throw new RuntimeException("Application cannot be rejected in current status: " + application.getStatus());
        }

        application.setStatus(ApplicationStatus.REJECTED);
        application.setReviewedAt(LocalDateTime.now());
        application.setReviewedBy(admin);
        application.setRejectionReason(reason);

        application = applicationRepository.save(application);

        adminActionLogService.log(
            admin,
            ActionType.REJECT_DRIVER_APPLICATION,
            "DriverApplication:" + id,
            "Rejected: " + reason
        );

        return mapToResponse(application);
    }

    @Transactional
    public DriverApplicationResponse updateApplicationStatus(Long id, ApplicationStatus newStatus, User admin) {
        DriverApplication application = applicationRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Application not found"));

        ApplicationStatus oldStatus = application.getStatus();
        application.setStatus(newStatus);

        if (newStatus == ApplicationStatus.UNDER_REVIEW && application.getReviewedBy() == null) {
            application.setReviewedBy(admin);
        }

        application = applicationRepository.save(application);

        adminActionLogService.log(
            admin,
            ActionType.UPDATE_DRIVER_APPLICATION,
            "DriverApplication:" + id,
            "Status changed from " + oldStatus + " to " + newStatus
        );

        return mapToResponse(application);
    }

    private DriverApplicationResponse mapToResponse(DriverApplication application) {
        DriverApplicationResponse response = new DriverApplicationResponse();
        response.setId(application.getId());
        response.setFullName(application.getFullName());
        response.setPhone(application.getPhone());
        response.setEmail(application.getEmail());
        response.setLicenseNumber(application.getLicenseNumber());
        response.setLicenseExpiry(application.getLicenseExpiry());
        response.setVehicleMake(application.getVehicleMake());
        response.setVehicleModel(application.getVehicleModel());
        response.setVehicleYear(application.getVehicleYear());
        response.setVehiclePlate(application.getVehiclePlate());
        response.setCarClass(application.getCarClass());
        response.setStatus(application.getStatus());
        response.setSubmittedAt(application.getSubmittedAt());
        response.setReviewedAt(application.getReviewedAt());
        response.setRejectionReason(application.getRejectionReason());
        response.setNotes(application.getNotes());

        if (application.getReviewedBy() != null) {
            response.setReviewedByName(application.getReviewedBy().getFullName());
        }

        return response;
    }
}
