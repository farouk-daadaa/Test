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
import project.repository.UserRepository;
import project.service.SessionService;

import javax.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/sessions")
@Validated
public class SessionController {

    @Autowired
    private SessionService sessionService;

    @Autowired
    private UserRepository userRepository;

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
            @PathVariable Long studentId) {
        List<SessionResponseDTO> sessions = sessionService.getAvailableSessions(studentId);
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