package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import project.dto.*;
import project.models.*;
import project.repository.*;
import project.security.JWTGenerator;

import javax.annotation.PostConstruct;
import javax.transaction.Transactional;
import java.util.*;

import project.service.EmailService;
import project.service.imageServiceImpl;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*", allowedHeaders = "*")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JWTGenerator jwtGenerator;
    private final RoleRepository roleRepository;

    @Autowired
    public AuthController(AuthenticationManager authenticationManager, UserRepository userRepository,
                          RoleRepository roleRepository, PasswordEncoder passwordEncoder, JWTGenerator jwtGenerator) {
        this.authenticationManager = authenticationManager;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtGenerator = jwtGenerator;
    }

    @Autowired
    private EmailService emailService;

    @Autowired
    private imageServiceImpl imageService;

    @Autowired
    private ImageRepository imageRepository;
    @Autowired
    private BookmarkRepository bookmarkRepository;
    @Autowired
    private EnrollmentRepository enrollmentRepository;
    @Autowired
    private ReviewRepository reviewRepository;
    @Autowired
    private InstructorRepository instructorRepository;
    @Autowired
    private CourseRepository courseRepository;

    @PostConstruct
    public void createDefaultAdminAccount() {
        if (!userRepository.existsByUsername("admin")) {
            UserEntity adminUser = new UserEntity();
            adminUser.setUsername("admin");
            adminUser.setEmail("admin@bridge.com");
            adminUser.setPassword(passwordEncoder.encode("admin")); // Default password
            adminUser.setFirstName("Admin");
            adminUser.setLastName("Bridge");
            adminUser.setCreationDate(new Date());
            UserRole adminRole = new UserRole();
            adminRole.setUserRoleName(UserRoleName.ADMIN);
            adminRole.setUserEntity(adminUser);
            adminUser.setUserRole(adminRole);
            userRepository.save(adminUser);
        }
    }

    @GetMapping("/validate-token")
    public ResponseEntity<?> validateToken(@RequestHeader("Authorization") String token) {
        try {
            if (token.startsWith("Bearer ")) {
                token = token.substring(7); // Remove "Bearer " prefix
            }
            boolean isValid = jwtGenerator.validateToken(token);
            return ResponseEntity.ok(isValid);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid or expired token");
        }
    }

    @PostMapping("login")
    public ResponseEntity<?> login(@RequestBody LoginDto loginDto) {
        System.out.println("Attempting login for username: " + loginDto.getUsername() + ", password: " + loginDto.getPassword());
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(
                            loginDto.getUsername(),
                            loginDto.getPassword()
                    )
            );
            System.out.println("Authentication successful for username: " + loginDto.getUsername());
            SecurityContextHolder.getContext().setAuthentication(authentication);
            UserDetails userDetails = (UserDetails) authentication.getPrincipal();
            String token = jwtGenerator.generateToken(authentication);

            Optional<UserEntity> userOptional = userRepository.findByUsername(userDetails.getUsername());
            if (userOptional.isPresent()) {
                UserEntity user = userOptional.get();
                AuthResponseDTO authResponseDTO = new AuthResponseDTO(token, user);
                System.out.println("Login successful, returning token: " + token);
                return new ResponseEntity<>(authResponseDTO, HttpStatus.OK);
            } else {
                System.out.println("User not found in database for username: " + userDetails.getUsername());
                return new ResponseEntity<>("User not found", HttpStatus.NOT_FOUND);
            }
        } catch (AuthenticationException e) {
            System.out.println("Authentication failed for username: " + loginDto.getUsername() + ". Error: " + e.getMessage());
            return new ResponseEntity<>("Invalid username or password", HttpStatus.UNAUTHORIZED);
        }
    }

    @PostMapping("register")
    public ResponseEntity<?> register(@RequestBody RegisterDto registerDto) {
        if (userRepository.existsByUsername(registerDto.getUsername())) {
            return ResponseEntity.badRequest().body("Username is taken!");
        }
        if (userRepository.existsByEmail(registerDto.getEmail())) {
            return ResponseEntity.badRequest().body("Email is already registered!");
        }

        UserEntity user = new UserEntity();
        user.setFirstName(registerDto.getFirstName());
        user.setLastName(registerDto.getLastName());
        user.setUsername(registerDto.getUsername());
        user.setEmail(registerDto.getEmail());
        user.setPassword(passwordEncoder.encode(registerDto.getPassword()));
        user.setPhoneNumber(registerDto.getPhoneNumber());
        user.setGender(registerDto.getGender());
        user.setCreationDate(new Date());

        UserRole defaultRole = new UserRole();
        defaultRole.setUserRoleName(UserRoleName.USER);
        defaultRole.setUserEntity(user);
        user.setUserRole(defaultRole);

        userRepository.save(user);
        imageService.createDefaultImage(user);

        return ResponseEntity.ok(user);
    }

    @PostMapping("/register/instructor")
    public ResponseEntity<?> registerInstructor(@RequestBody InstructorRegisterDto registerDto) {
        if (userRepository.existsByUsername(registerDto.getUsername())) {
            return ResponseEntity.badRequest().body("Username is taken!");
        }
        if (userRepository.existsByEmail(registerDto.getEmail())) {
            return ResponseEntity.badRequest().body("Email is already registered!");
        }

        UserEntity user = new UserEntity();
        user.setFirstName(registerDto.getFirstName());
        user.setLastName(registerDto.getLastName());
        user.setUsername(registerDto.getUsername());
        user.setEmail(registerDto.getEmail());
        user.setPassword(passwordEncoder.encode(registerDto.getPassword()));
        user.setPhoneNumber(registerDto.getPhone());
        user.setGender(registerDto.getGender());
        user.setCreationDate(new Date());

        UserRole instructorRole = new UserRole();
        instructorRole.setUserRoleName(UserRoleName.INSTRUCTOR);
        instructorRole.setUserEntity(user);
        user.setUserRole(instructorRole);

        Instructor instructor = new Instructor();
        instructor.setUser(user);
        instructor.setPhone(registerDto.getPhone());
        instructor.setCv(registerDto.getCv());
        instructor.setLinkedinLink(registerDto.getLinkedinLink());
        instructor.setStatus(InstructorStatus.PENDING);
        user.setInstructor(instructor);

        userRepository.save(user);
        imageService.createDefaultImage(user);
        emailService.sendInstructorSignUpEmail(user.getEmail());

        Map<String, String> response = new HashMap<>();
        response.put("message", "Instructor registered successfully. Waiting for admin approval.");
        return ResponseEntity.ok(response);
    }

    @Transactional
    @DeleteMapping("/delete/{username}")
    public ResponseEntity<?> deleteUser(@PathVariable String username) {
        try {
            Optional<UserEntity> userOptional = userRepository.findByUsername(username);
            if (!userOptional.isPresent()) {
                return ResponseEntity.notFound().build();
            }

            UserEntity user = userOptional.get();
            Long userId = user.getId();

            imageRepository.deleteByUserEntityId(userId);
            bookmarkRepository.deleteByUser(user);
            enrollmentRepository.deleteByStudent(user);
            reviewRepository.deleteByUser(user);

            Optional<Instructor> instructorOptional = instructorRepository.findByUser(user);
            if (instructorOptional.isPresent()) {
                Instructor instructor = instructorOptional.get();
                Long instructorId = instructor.getId();
                List<Course> courses = courseRepository.findByInstructorId(instructorId);
                for (Course course : courses) {
                    Optional<Enrollment> enrollmentOptional = enrollmentRepository.findByCourseAndStudent(course, user);
                    if (enrollmentOptional.isPresent()) {
                        enrollmentRepository.delete(enrollmentOptional.get());
                    }
                }
                courseRepository.deleteByInstructorId(instructorId);
            }

            userRepository.delete(user);

            Map<String, String> response = new HashMap<>();
            response.put("message", "Account deleted successfully");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.status(500).body("Failed to delete account: " + e.getMessage());
        }
    }

    @GetMapping("/user/id/{username}")
    public ResponseEntity<Map<String, Integer>> getUserIdByUsername(@PathVariable String username) {
        Optional<UserEntity> userOptional = userRepository.findByUsername(username);
        if (userOptional.isPresent()) {
            Map<String, Integer> response = new HashMap<>();
            response.put("id", userOptional.get().getId().intValue());
            return ResponseEntity.ok(response);
        } else {
            return ResponseEntity.notFound().build();
        }
    }

    @GetMapping("/user/{username}")
    public ResponseEntity<UserDTO> getUserByUsername(@PathVariable String username) {
        System.out.println("Fetching user details for username: " + username);
        Optional<UserEntity> userOptional = userRepository.findByUsername(username);
        if (userOptional.isPresent()) {
            System.out.println("User found with ID: " + userOptional.get().getId());
            try {
                UserDTO userDTO = UserDTO.fromEntity(userOptional.get());
                System.out.println("Successfully mapped to UserDTO: " + userDTO.getUsername());
                return ResponseEntity.ok(userDTO);
            } catch (Exception e) {
                System.out.println("Error mapping to UserDTO: " + e.getMessage());
                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(null);
            }
        } else {
            System.out.println("User not found for username: " + username);
            return ResponseEntity.notFound().build();
        }
    }

    @PutMapping("/update/{username}")
    public ResponseEntity<?> updateUser(@PathVariable String username, @RequestBody UserDTO userDto) {
        System.out.println("Updating user with username: " + username);
        Optional<UserEntity> userOptional = userRepository.findByUsername(username);
        if (!userOptional.isPresent()) {
            System.out.println("User not found for username: " + username);
            return ResponseEntity.notFound().build();
        }

        UserEntity user = userOptional.get();
        System.out.println("Found user with ID: " + user.getId());

        if (userDto.getFirstName() != null) user.setFirstName(userDto.getFirstName());
        if (userDto.getLastName() != null) user.setLastName(userDto.getLastName());
        if (userDto.getEmail() != null) {
            if (!userDto.getEmail().equals(user.getEmail()) && userRepository.existsByEmail(userDto.getEmail())) {
                return ResponseEntity.badRequest().body("Email is already registered!");
            }
            user.setEmail(userDto.getEmail());
        }
        if (userDto.getPhoneNumber() != null) user.setPhoneNumber(userDto.getPhoneNumber());
        if (userDto.getUsername() != null) {
            if (!userDto.getUsername().equals(user.getUsername()) && userRepository.existsByUsername(userDto.getUsername())) {
                return ResponseEntity.badRequest().body("Username is already taken!");
            }
            user.setUsername(userDto.getUsername());
        }

        userRepository.save(user);
        System.out.println("User updated successfully with username: " + user.getUsername());
        return ResponseEntity.ok(UserDTO.fromEntity(user));
    }

    @PutMapping("/update-password/{username}")
    public ResponseEntity<?> updatePassword(@PathVariable String username, @RequestBody Map<String, String> passwordData) {
        Optional<UserEntity> userOptional = userRepository.findByUsername(username);
        if (!userOptional.isPresent()) {
            return ResponseEntity.notFound().build();
        }

        UserEntity user = userOptional.get();
        String currentPassword = passwordData.get("currentPassword");
        String newPassword = passwordData.get("newPassword");

        if (!passwordEncoder.matches(currentPassword, user.getPassword())) {
            return ResponseEntity.badRequest().body("Current password is incorrect");
        }
        if (newPassword == null || newPassword.length() < 8) {
            return ResponseEntity.badRequest().body("New password must be at least 8 characters");
        }

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        Map<String, String> response = new HashMap<>();
        response.put("message", "Password updated successfully");
        return ResponseEntity.ok(response);
    }
}