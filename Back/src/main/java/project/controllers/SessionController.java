package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
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
import project.repository.InstructorRepository;
import project.repository.SessionRepository;
import project.repository.UserRepository;
import project.service.SessionService;

import javax.validation.Valid;
import java.util.List;
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

    @PostMapping("/create")
    @PreAuthorize("hasRole('INSTRUCTOR')")
    public ResponseEntity<SessionResponseDTO> createSession(
            @Valid @RequestBody SessionRequestDTO sessionRequestDTO,
            Authentication authentication) {
        SessionResponseDTO responseDTO = sessionService.createSession(sessionRequestDTO, authentication);
        return new ResponseEntity<>(responseDTO, HttpStatus.CREATED);
    }

    @GetMapping("/student/{studentId}")
    public ResponseEntity<List<SessionResponseDTO>> getAvailableSessions(
            @PathVariable Long studentId,
            @RequestParam(required = false) String status) {
        List<SessionResponseDTO> sessions = sessionService.getAvailableSessions(studentId, status);
        return ResponseEntity.ok(sessions);
    }

    @GetMapping("/join/{sessionId}")
    public ResponseEntity<String> joinSession(
            @PathVariable Long sessionId,
            Authentication authentication) {
        Long studentId = getStudentIdFromAuthentication(authentication);
        String meetingLink = sessionService.joinSession(sessionId, studentId);
        return ResponseEntity.ok(meetingLink);
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

    // Optional: Get all sessions for the authenticated instructor
    @GetMapping("/my-sessions")
    @PreAuthorize("hasRole('INSTRUCTOR')")
    public ResponseEntity<List<SessionResponseDTO>> getMySessions(Authentication authentication) {
        String username = authentication.getName();
        Instructor instructor = userRepository.findByUsername(username)
                .map(userEntity -> userEntity.getInstructor())
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