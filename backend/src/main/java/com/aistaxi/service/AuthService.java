package com.aistaxi.service;

import com.aistaxi.dto.AuthResponse;
import com.aistaxi.dto.LoginRequest;
import com.aistaxi.dto.RegisterRequest;
import com.aistaxi.model.*;
import com.aistaxi.repository.DriverDetailsRepository;
import com.aistaxi.repository.UserRepository;
import com.aistaxi.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final DriverDetailsRepository driverDetailsRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        log.info("Registration attempt for phone: {}, role: {}", request.getPhone(), request.getRole());

        if (userRepository.findByPhone(request.getPhone()).isPresent()) {
            log.warn("Registration failed - phone already registered: {}", request.getPhone());
            throw new RuntimeException("Phone number already registered");
        }

        User user = new User();
        user.setPhone(request.getPhone());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setFullName(request.getFullName());
        user.setRole(request.getRole());

        log.debug("Saving user to database");
        User savedUser = userRepository.saveAndFlush(user);
        log.info("User registered successfully with id: {}", savedUser.getId());

        if (savedUser.getRole() == Role.DRIVER) {
            log.debug("Creating DriverDetails for user: {}", savedUser.getId());
            DriverDetails details = new DriverDetails();
            details.setUser(savedUser);
            // Don't set userId manually — @MapsId derives it from the user association
            details.setCarClass(CarClass.ECONOMY);
            details.setCarModel("Generic Car");
            details.setCarNumber("000 AAA 01");
            details.setStatus(DriverStatus.OFFLINE);
            details.setCurrentLat(42.8746);
            details.setCurrentLon(74.5698);
            driverDetailsRepository.save(details);
            log.info("DriverDetails created for user: {}", savedUser.getId());
        }

        String token = jwtUtil.generateToken(savedUser);
        log.debug("JWT token generated for user: {}", savedUser.getId());

        return new AuthResponse(token, savedUser.getRole(), savedUser.getId());
    }

    public AuthResponse login(LoginRequest request) {
        log.info("Login attempt for phone: {}", request.getPhone());
        User user = userRepository.findByPhone(request.getPhone())
                .orElseThrow(() -> {
                    log.warn("Login failed - user not found: {}", request.getPhone());
                    return new RuntimeException("User not found");
                });

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            log.warn("Login failed - invalid password for user: {}", request.getPhone());
            throw new RuntimeException("Invalid credentials");
        }

        log.info("Login successful for user: {}, role: {}", request.getPhone(), user.getRole());
        String token = jwtUtil.generateToken(user);
        return new AuthResponse(token, user.getRole(), user.getId());
    }
}
