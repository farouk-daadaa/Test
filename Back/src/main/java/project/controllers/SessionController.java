package project.controllers;

import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import project.dto.SessionRequestDTO;
import project.dto.SessionResponseDTO;
import project.models.Instructor;
import project.models.Session;
import project.models.UserEntity;
import project.models.UserRoleName;
import project.repository.SessionRepository;
import project.repository.UserRepository;
import project.service.SessionService;

import javax.validation.Valid;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
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

    @Value("${daily.api.key}")
    private String DAILY_API_KEY;

    private static final String DAILY_API_URL = "https://api.daily.co/v1/";

    private final HttpClient httpClient = HttpClient.newHttpClient();

    @PostMapping("/create")
    @PreAuthorize("hasRole('INSTRUCTOR')")
    public ResponseEntity<Map<String, Object>> createSession(
            @Valid @RequestBody SessionRequestDTO sessionRequestDTO,
            Authentication authentication) throws Exception {

        // Generate a unique room name for Daily
        String roomName = "session-" + System.currentTimeMillis();
        String roomUrl = createDailyRoom(roomName);

        // Create the session in the database with the meetingLink
        SessionResponseDTO responseDTO = sessionService.createSession(sessionRequestDTO, authentication, roomUrl);

        // Generate a meeting token for the instructor (with is_owner)
        String instructorToken = createDailyMeetingToken(true);

        // Update the response DTO with the meeting link
        responseDTO.setMeetingLink(roomUrl);

        // Return session details along with the instructor's meeting token
        Map<String, Object> response = new HashMap<>();
        response.put("session", responseDTO);
        response.put("meetingToken", instructorToken);

        return new ResponseEntity<>(response, HttpStatus.CREATED);
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
            Authentication authentication) throws Exception {

        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));

        Session session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalStateException("Session not found: " + sessionId));

        // Get the instructor ID of the session creator
        Long creatorInstructorId = session.getInstructorId();
        Instructor currentInstructor = user.getInstructor();
        boolean isOriginalCreator = currentInstructor != null && creatorInstructorId != null && currentInstructor.getId().equals(creatorInstructorId);

        // If the user is not the original creator (i.e., not an instructor or not the creator),
        // treat them as a student and check if they can join
        if (!isOriginalCreator) {
            Long studentId = user.getId();
            sessionService.joinSession(sessionId, studentId); // This will throw an exception if the student can't join
        }

        String meetingLink = session.getMeetingLink();

        // Generate a meeting token: is_owner only for the original creator, false for all others
        String meetingToken = createDailyMeetingToken(isOriginalCreator);

        Map<String, String> response = new HashMap<>();
        response.put("meetingLink", meetingLink);
        response.put("meetingToken", meetingToken);

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

    private String createDailyRoom(String roomName) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(DAILY_API_URL + "rooms"))
                .header("Authorization", "Bearer " + DAILY_API_KEY)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(
                        "{\"name\":\"" + roomName + "\",\"properties\":{\"enable_chat\":true}}"))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new RuntimeException("Failed to create Daily room: " + response.body());
        }

        JSONObject json = new JSONObject(response.body());
        return json.getString("url");
    }

    private String createDailyMeetingToken(boolean isOwner) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(DAILY_API_URL + "meeting-tokens"))
                .header("Authorization", "Bearer " + DAILY_API_KEY)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(
                        "{\"properties\":{\"is_owner\":" + isOwner + "}}"))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new RuntimeException("Failed to create Daily meeting token: " + response.body());
        }

        JSONObject json = new JSONObject(response.body());
        return json.getString("token");
    }
}