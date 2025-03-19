package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import project.dto.SessionRequestDTO;
import project.dto.SessionResponseDTO;
import project.exception.AccessDeniedException;
import project.models.Instructor;
import project.models.Session;
import project.models.UserEntity;
import project.repository.SessionRepository;
import project.repository.UserRepository;
import project.security.HmsTokenService;
import project.service.SessionService;

import javax.validation.Valid;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/sessions")
@Validated
public class SessionController {

    @Autowired
    private SessionService sessionService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SessionRepository sessionRepository;

    @Autowired
    private HmsTokenService hmsTokenService;

    @Value("${hms.room.endpoint}")
    private String HMS_ROOM_ENDPOINT;

    @Value("${hms.template.id}")
    private String HMS_TEMPLATE_ID;

    @Value("${hms.management.token}")
    private String HMS_MANAGEMENT_TOKEN;

    private final RestTemplate restTemplate = new RestTemplate();

    @PostMapping("/create")
    @PreAuthorize("hasRole('INSTRUCTOR')")
    public ResponseEntity<Map<String, Object>> createSession(
            @Valid @RequestBody SessionRequestDTO sessionRequestDTO,
            Authentication authentication) {

        // Create the session in the database
        SessionResponseDTO responseDTO = sessionService.createSession(sessionRequestDTO, authentication, null);

        // Create a new room in 100ms
        String roomId;
        try {
            roomId = createHmsRoom(sessionRequestDTO.getTitle());
        } catch (Exception e) {
            throw new RuntimeException("Failed to create 100ms room: " + e.getMessage());
        }

        // Update session with the new room_id
        Session session = sessionRepository.findById(responseDTO.getId())
                .orElseThrow(() -> new IllegalStateException("Session not found after creation: " + responseDTO.getId()));
        session.setMeetingLink("room://" + roomId);
        sessionRepository.save(session);
        responseDTO.setMeetingLink("room://" + roomId); // Update the DTO

        // Return session details (no token yet, generated on join)
        Map<String, Object> response = new HashMap<>();
        response.put("session", responseDTO);

        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    // Helper method to create a room in 100ms
    private String createHmsRoom(String sessionTitle) {
        Map<String, String> body = new HashMap<>();
        body.put("name", "session-" + sessionTitle + "-" + System.currentTimeMillis()); // Unique name
        body.put("description", "Room for session: " + sessionTitle);
        body.put("template_id", HMS_TEMPLATE_ID);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Authorization", "Bearer " + HMS_MANAGEMENT_TOKEN);

        HttpEntity<Map<String, String>> entity = new HttpEntity<>(body, headers);
        ResponseEntity<Map> response = restTemplate.postForEntity(HMS_ROOM_ENDPOINT, entity, Map.class);

        if (response.getStatusCode() != HttpStatus.OK) {
            throw new RuntimeException("Failed to create room: " + response.getBody());
        }

        return (String) response.getBody().get("id"); // Extract room_id
    }

    @GetMapping("/student/{studentId}")
    public ResponseEntity<List<SessionResponseDTO>> getAvailableSessions(
            @PathVariable Long studentId,
            @RequestParam(required = false) String status) {
        List<SessionResponseDTO> sessions = sessionService.getAvailableSessions(studentId, status);
        return ResponseEntity.ok(sessions);
    }

    @GetMapping("/join/{sessionId}")
    public ResponseEntity<Map<String, String>> joinSession(
            @PathVariable Long sessionId,
            Authentication authentication) {

        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));

        Session session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalStateException("Session not found: " + sessionId));

        // Determine the user's role and enforce security
        Long creatorInstructorId = session.getInstructorId();
        Instructor currentInstructor = user.getInstructor();
        String role;
        boolean isAuthorized = false;

        // Check if the user is an admin
        boolean isAdmin = authentication.getAuthorities().contains(new SimpleGrantedAuthority("ROLE_ADMIN"));
        if (isAdmin) {
            role = "instructor"; // Admins always join as instructors
            isAuthorized = true; // Admins can join any session
        } else if (currentInstructor != null) {
            // User is an instructor
            boolean isOriginalCreator = creatorInstructorId != null && currentInstructor.getId().equals(creatorInstructorId);
            if (isOriginalCreator) {
                role = "instructor"; // Only the creator gets instructor role
                isAuthorized = true;
            } else {
                role = "student"; // Other instructors get student role
                isAuthorized = true; // Allow them to join as students
            }
        } else {
            // User is a student
            role = "student";
            // Check follower-only restriction
            List<Instructor> followedInstructors = user.getFollowedInstructors();
            isAuthorized = !session.isFollowerOnly() || followedInstructors.contains(session.getInstructor());
        }

        if (!isAuthorized) {
            throw new AccessDeniedException("You are not authorized to join this session. " +
                    (session.isFollowerOnly() ? "This is a follower-only session, and you do not follow the instructor." : ""));
        }

        // Extract room_id from meetingLink
        String roomId = session.getMeetingLink().replace("room://", "");

        // Generate a 100ms auth token using the new service
        String meetingToken = hmsTokenService.generateHmsToken(roomId, username, role);

        Map<String, String> response = new HashMap<>();
        response.put("meetingLink", session.getMeetingLink());
        response.put("meetingToken", meetingToken);
        response.put("roomId", roomId); // Include roomId for clarity in the client

        return ResponseEntity.ok(response);
    }

    @PutMapping("/{sessionId}")
    @PreAuthorize("hasRole('INSTRUCTOR')")
    public ResponseEntity<SessionResponseDTO> updateSession(
            @PathVariable Long sessionId,
            @Valid @RequestBody SessionRequestDTO sessionRequestDTO,
            Authentication authentication) {
        SessionResponseDTO responseDTO = sessionService.updateSession(sessionId, sessionRequestDTO, authentication);
        return ResponseEntity.ok(responseDTO);
    }

    @DeleteMapping("/{sessionId}")
    @PreAuthorize("hasRole('INSTRUCTOR')")
    public ResponseEntity<Void> deleteSession(
            @PathVariable Long sessionId,
            Authentication authentication) {
        sessionService.deleteSession(sessionId, authentication);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/my-sessions")
    @PreAuthorize("hasRole('INSTRUCTOR')")
    public ResponseEntity<List<SessionResponseDTO>> getMySessions(Authentication authentication) {
        String username = authentication.getName();
        Instructor instructor = userRepository.findByUsername(username)
                .map(UserEntity::getInstructor)
                .orElseThrow(() -> new IllegalStateException("Instructor not found for user: " + username));
        List<Session> sessions = sessionRepository.findByInstructor(instructor);
        List<SessionResponseDTO> responseDTOs = sessions.stream()
                .map(SessionResponseDTO::fromEntity)
                .collect(Collectors.toList());
        return ResponseEntity.ok(responseDTOs);
    }

    private Long getStudentIdFromAuthentication(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalStateException("User is not authenticated");
        }
        String username = authentication.getName();
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username))
                .getId();
    }
}