# Next Steps Plan
## Date: 2026-05-11

### Immediate Priorities (High Impact)

#### 1. Add Input Validation (1-2 hours)
**Why:** Prevent invalid data from entering the system
**Files to modify:**
- `DriverApplicationRequest.java`
- `RegisterRequest.java`
- `LoginRequest.java`

**Changes:**
```java
@Data
public class DriverApplicationRequest {
    @NotBlank(message = "Full name is required")
    @Size(min = 2, max = 100)
    private String fullName;
    
    @NotBlank(message = "Phone is required")
    @Pattern(regexp = "^\\+996\\d{9}$", message = "Invalid phone format")
    private String phone;
    
    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;
    
    @NotBlank(message = "License number is required")
    private String licenseNumber;
    
    @NotNull(message = "Car class is required")
    private CarClass carClass;
    
    // ... rest of fields
}
```

**Controllers to update:**
- Add `@Valid` annotation to `@RequestBody` parameters
- Add `@Validated` to controller classes

#### 2. Replace Console Logging (30 minutes)
**Why:** Proper logging for production environments

**Add dependency to pom.xml:**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-logging</artifactId>
</dependency>
```

**Replace in all services:**
```java
// Before:
System.out.println("Driver activated: " + driver.getPhone());

// After:
@Slf4j
public class DriverManagementService {
    log.info("Driver activated: phone={}, id={}", driver.getPhone(), driver.getId());
}
```

**Files to update:**
- `DriverManagementService.java`
- `AuthController.java`
- `AdminController.java`

#### 3. Add Pagination (2-3 hours)
**Why:** Performance and scalability

**Add to repositories:**
```java
public interface DriverApplicationRepository extends JpaRepository<DriverApplication, Long> {
    Page<DriverApplication> findByStatus(ApplicationStatus status, Pageable pageable);
}
```

**Update service methods:**
```java
public Page<DriverApplicationResponse> getAllApplications(
    ApplicationStatus status, 
    int page, 
    int size
) {
    Pageable pageable = PageRequest.of(page, size, Sort.by("submittedAt").descending());
    Page<DriverApplication> applications = applicationRepository.findByStatus(status, pageable);
    return applications.map(this::mapToResponse);
}
```

**Update controller endpoints:**
```java
@GetMapping("/driver-applications")
public ResponseEntity<Page<DriverApplicationResponse>> getDriverApplications(
    @RequestParam(required = false) ApplicationStatus status,
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int size
) {
    Page<DriverApplicationResponse> applications = 
        driverApplicationService.getAllApplications(status, page, size);
    return ResponseEntity.ok(applications);
}
```

### Medium Priority (Quality Improvements)

#### 4. Add Unit Tests (4-6 hours)
**Test coverage targets:**
- Services: 80%+
- Controllers: 70%+
- Repositories: Basic CRUD tests

**Example test structure:**
```java
@SpringBootTest
class DriverApplicationServiceTest {
    
    @MockBean
    private DriverApplicationRepository applicationRepository;
    
    @MockBean
    private UserRepository userRepository;
    
    @Autowired
    private DriverApplicationService service;
    
    @Test
    void submitApplication_Success() {
        // Given
        DriverApplicationRequest request = new DriverApplicationRequest();
        request.setPhone("+996700000001");
        
        when(userRepository.findByPhone(anyString())).thenReturn(Optional.empty());
        when(applicationRepository.findByPhone(anyString())).thenReturn(Optional.empty());
        
        // When
        DriverApplicationResponse response = service.submitApplication(request);
        
        // Then
        assertNotNull(response);
        assertEquals(ApplicationStatus.PENDING, response.getStatus());
        verify(applicationRepository).save(any());
    }
    
    @Test
    void submitApplication_DuplicatePhone_ThrowsException() {
        // Given
        DriverApplicationRequest request = new DriverApplicationRequest();
        request.setPhone("+996700000001");
        
        when(userRepository.findByPhone(anyString())).thenReturn(Optional.of(new User()));
        
        // When & Then
        assertThrows(RuntimeException.class, () -> service.submitApplication(request));
    }
}
```

#### 5. Externalize Configuration (1 hour)
**Create:** `application-messages.properties`
```properties
error.phone.duplicate=Phone number already registered
error.application.exists=Application already submitted for this phone number
error.plate.duplicate=Vehicle plate already registered
error.application.notfound=Application not found
error.driver.notfound=Driver not found
error.invalid.status=Application cannot be {0} in current status: {1}

success.driver.activated=Driver activated successfully
success.driver.terminated=Driver terminated successfully
success.documents.verified=Documents verified successfully
```

**Update services to use MessageSource:**
```java
@Service
@RequiredArgsConstructor
public class DriverApplicationService {
    private final MessageSource messageSource;
    
    public DriverApplicationResponse submitApplication(DriverApplicationRequest request) {
        if (userRepository.findByPhone(request.getPhone()).isPresent()) {
            throw new RuntimeException(
                messageSource.getMessage("error.phone.duplicate", null, LocaleContextHolder.getLocale())
            );
        }
        // ...
    }
}
```

### Low Priority (Nice to Have)

#### 6. Add API Documentation (2 hours)
**Add Swagger/OpenAPI:**
```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.1.0</version>
</dependency>
```

**Add annotations:**
```java
@RestController
@RequestMapping("/api/admin")
@Tag(name = "Admin", description = "Admin management APIs")
public class AdminController {
    
    @Operation(summary = "Get dashboard metrics")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Metrics retrieved"),
        @ApiResponse(responseCode = "401", description = "Unauthorized")
    })
    @GetMapping("/dashboard/metrics")
    public ResponseEntity<Map<String, Object>> getDashboardMetrics() {
        // ...
    }
}
```

#### 7. Add Rate Limiting (2-3 hours)
**Use Bucket4j:**
```xml
<dependency>
    <groupId>com.github.vladimir-bukhtoyarov</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>8.1.0</version>
</dependency>
```

**Create rate limiter:**
```java
@Component
public class RateLimitInterceptor implements HandlerInterceptor {
    
    private final Map<String, Bucket> cache = new ConcurrentHashMap<>();
    
    @Override
    public boolean preHandle(HttpServletRequest request, 
                            HttpServletResponse response, 
                            Object handler) {
        String key = request.getRemoteAddr();
        Bucket bucket = cache.computeIfAbsent(key, k -> createBucket());
        
        if (bucket.tryConsume(1)) {
            return true;
        }
        
        response.setStatus(429);
        return false;
    }
    
    private Bucket createBucket() {
        return Bucket.builder()
            .addLimit(Bandwidth.simple(100, Duration.ofMinutes(1)))
            .build();
    }
}
```

### External Integrations (Requires Infrastructure)

#### 8. SMS Service Integration (3-4 hours)
**Options:**
- Twilio
- AWS SNS
- Local SMS gateway

**Implementation:**
```java
@Service
@RequiredArgsConstructor
public class SmsService {
    
    @Value("${sms.provider.api-key}")
    private String apiKey;
    
    public void sendDriverActivationSms(String phone, String tempPassword) {
        String message = String.format(
            "Welcome to AIS Taxi! Your account is activated. " +
            "Phone: %s, Temporary Password: %s. " +
            "Please change your password after first login.",
            phone, tempPassword
        );
        
        // Send via SMS provider
        smsProvider.send(phone, message);
    }
    
    public void sendDriverTerminationSms(String phone, String reason) {
        String message = String.format(
            "Your AIS Taxi driver account has been terminated. Reason: %s. " +
            "Contact support for more information.",
            reason
        );
        
        smsProvider.send(phone, message);
    }
}
```

#### 9. File Storage for Documents (4-5 hours)
**Options:**
- MinIO (self-hosted S3-compatible)
- AWS S3
- Local filesystem

**Implementation:**
```java
@Service
@RequiredArgsConstructor
public class DocumentStorageService {
    
    @Value("${storage.bucket-name}")
    private String bucketName;
    
    private final MinioClient minioClient;
    
    public String uploadDocument(Long driverId, 
                                 String documentType, 
                                 MultipartFile file) {
        String objectName = String.format(
            "drivers/%d/%s/%s",
            driverId,
            documentType,
            file.getOriginalFilename()
        );
        
        minioClient.putObject(
            PutObjectArgs.builder()
                .bucket(bucketName)
                .object(objectName)
                .stream(file.getInputStream(), file.getSize(), -1)
                .contentType(file.getContentType())
                .build()
        );
        
        return objectName;
    }
}
```

**Add entity:**
```java
@Entity
@Table(name = "driver_documents")
public class DriverDocument {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "driver_id")
    private User driver;
    
    @Enumerated(EnumType.STRING)
    private DocumentType type; // LICENSE, PASSPORT, VEHICLE_REGISTRATION
    
    private String storageKey;
    private String originalFilename;
    private LocalDateTime uploadedAt;
    
    @Enumerated(EnumType.STRING)
    private VerificationStatus status; // PENDING, APPROVED, REJECTED
    
    private String rejectionReason;
}
```

### Remaining Admin Panel Tasks (6 tasks)

#### Task #13: Transaction System (4-5 hours)
**Entities:**
- Transaction
- TransactionType (RIDE_PAYMENT, PAYOUT, REFUND, ADJUSTMENT)

**Endpoints:**
- GET /api/admin/transactions
- GET /api/admin/transactions/{id}
- POST /api/admin/transactions/refund
- POST /api/admin/transactions/adjustment

#### Task #5: Promo Code System (3-4 hours)
**Entities:**
- PromoCode
- PromoCodeUsage

**Endpoints:**
- GET /api/admin/promo-codes
- POST /api/admin/promo-codes
- PUT /api/admin/promo-codes/{id}
- DELETE /api/admin/promo-codes/{id}

#### Task #8: Review System (2-3 hours)
**Entities:**
- Review
- ReviewResponse

**Endpoints:**
- GET /api/admin/reviews
- GET /api/admin/reviews/{id}
- POST /api/admin/reviews/{id}/respond

#### Task #4: Extend Ride Model (2-3 hours)
**Add fields:**
- cancellationReason
- cancelledBy
- promoCodeId
- refundAmount
- refundedAt

#### Task #10: Support Ticket System (4-5 hours)
**Entities:**
- SupportTicket
- TicketMessage
- TicketStatus

**Endpoints:**
- GET /api/admin/tickets
- GET /api/admin/tickets/{id}
- POST /api/admin/tickets/{id}/assign
- POST /api/admin/tickets/{id}/resolve
- POST /api/admin/tickets/{id}/messages

#### Task #2: Admin Panel Frontend (5-7 days)
**Technology:** React + TypeScript + Ant Design
**Pages:**
- Dashboard
- User Management
- Driver Management
- Driver Applications
- Ride Management
- Financial Reports
- Support Tickets
- Settings

### Timeline Estimate

**Week 1 (Immediate + Medium Priority):**
- Day 1: Validation + Logging (2-3 hours)
- Day 2: Pagination (2-3 hours)
- Day 3-4: Unit Tests (8-10 hours)
- Day 5: Configuration + Documentation (3-4 hours)

**Week 2 (Remaining Backend Tasks):**
- Day 1-2: Transaction System (8-10 hours)
- Day 3: Promo Code System (6-8 hours)
- Day 4: Review System + Ride Extensions (8-10 hours)
- Day 5: Support Ticket System (8-10 hours)

**Week 3 (External Integrations):**
- Day 1-2: SMS Service (6-8 hours)
- Day 3-4: File Storage + Document Management (8-10 hours)
- Day 5: Rate Limiting + Polish (4-6 hours)

**Week 4-5 (Frontend):**
- 10 days for complete admin panel UI

**Total Estimate: 4-5 weeks for complete admin panel**

---

**Plan created:** 2026-05-11T16:28:32Z
**Current progress:** 10/16 tasks (62.5%)
**Estimated completion:** 2026-06-08 (4 weeks from now)
