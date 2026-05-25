package com.aistaxi.config;

import com.aistaxi.model.Role;
import com.aistaxi.model.User;
import com.aistaxi.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class AdminInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        // Create default admin if not exists
        String adminPhone = "+996700000000";

        if (userRepository.findByPhone(adminPhone).isEmpty()) {
            User admin = new User();
            admin.setPhone(adminPhone);
            admin.setPassword(passwordEncoder.encode("admin123"));
            admin.setFullName("System Admin");
            admin.setRole(Role.ADMIN);
            admin.setRating(5.0);
            admin.setRatingCount(0);

            userRepository.save(admin);

            log.info("=================================================");
            log.info("Default admin created:");
            log.info("Phone: {}", adminPhone);
            log.info("Password: admin123");
            log.info("=================================================");
        }
    }
}
