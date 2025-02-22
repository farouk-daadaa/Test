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
import project.dto.AuthResponseDTO;
import project.dto.InstructorRegisterDto;
import project.dto.LoginDto;
import project.dto.RegisterDto;
import project.models.*;
import project.repository.RoleRepository;
import project.repository.UserRepository;
import project.security.JWTGenerator;

import javax.annotation.PostConstruct;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
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
                          RoleRepository roleRepository, PasswordEncoder passwordEncoder, JWTGenerator jwtGenerator
                          ) {
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

    @PostConstruct
    public void createDefaultAdminAccount() {
        if (!userRepository.existsByUsername("admin")) {
            UserEntity adminUser = new UserEntity();
            adminUser.setUsername("admin");
            adminUser.setEmail("admin@bridge.com");
            adminUser.setPassword(passwordEncoder.encode("admin")); // You can change the default password
            adminUser.setFirstName("Admin");
            adminUser.setLastName("Bridge");
            adminUser.setCreationDate(new Date());
            UserRole adminRole = new UserRole();
            adminRole.setUserRoleName(UserRoleName.ADMIN);
            adminRole.setUserEntity(adminUser);

            //---Access
           // adminRole.setEventManagement(true);
           // adminRole.setEventManagement(true);
            //--------

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
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(
                            loginDto.getUsername(),
                            loginDto.getPassword()
                    )
            );

            SecurityContextHolder.getContext().setAuthentication(authentication);
            UserDetails userDetails = (UserDetails) authentication.getPrincipal();
            String token = jwtGenerator.generateToken(authentication);

            Optional<UserEntity> userOptional = userRepository.findByUsername(userDetails.getUsername());
            if (userOptional.isPresent()) {
                UserEntity user = userOptional.get();
                AuthResponseDTO authResponseDTO = new AuthResponseDTO(token, user);
                return new ResponseEntity<>(authResponseDTO, HttpStatus.OK);
            } else {
                return new ResponseEntity<>("User not found", HttpStatus.NOT_FOUND);
            }

        } catch (AuthenticationException e) {
            return new ResponseEntity<>("Invalid username or password", HttpStatus.UNAUTHORIZED);
        }
    }



    @PostMapping("register")
    public ResponseEntity<?> register(@RequestBody RegisterDto registerDto) {
        if (userRepository.existsByUsername(registerDto.getUsername())) {
            return ResponseEntity.badRequest().body("Username is taken!");
        }

        // Check if the email is already registered
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

        // Set creationDate to the current date
        user.setCreationDate(new Date());



        UserRole defaultRole = new UserRole();
        defaultRole.setUserRoleName(UserRoleName.USER);
        defaultRole.setUserEntity(user);

        //defaultRole.setUserManagement(true);
        //defaultRole.setEventManagement(false);
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

        // Send confirmation email
        emailService.sendInstructorSignUpEmail(user.getEmail());

        Map<String, String> response = new HashMap<>();
        response.put("message", "Instructor registered successfully. Waiting for admin approval.");
        return ResponseEntity.ok(response);    }


    @DeleteMapping("delete/{username}")
    public ResponseEntity<?> deleteUser(@PathVariable String username) {
        // Recherche de l'utilisateur dans la base de données
        Optional<UserEntity> userOptional = userRepository.findByUsername(username);
        if (userOptional.isPresent()) {
            // L'utilisateur existe, le supprimer de la base de données
            userRepository.delete(userOptional.get());
            return ResponseEntity.ok("User deleted successfully");
        } else {
            // L'utilisateur n'existe pas dans la base de données
            return ResponseEntity.notFound().build();
        }
    }


}
