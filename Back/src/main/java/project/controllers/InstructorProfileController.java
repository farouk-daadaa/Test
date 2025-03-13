package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.InstructorProfileDTO;
import project.models.Instructor;
import project.repository.InstructorRepository;
import project.repository.UserRepository;

@RestController
@RequestMapping("/api/instructors")
public class InstructorProfileController {

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private UserRepository userRepository;

    @GetMapping(value = "/{instructorId}/profile", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<InstructorProfileDTO> getInstructorProfile(
            @PathVariable Long instructorId,
            Authentication authentication) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found with id: " + instructorId));

        Long currentUserId = authentication != null ? getUserIdFromAuthentication(authentication) : null;
        InstructorProfileDTO profileDTO = InstructorProfileDTO.fromEntity(instructor, currentUserId);
        return ResponseEntity.ok(profileDTO);
    }

    private Long getUserIdFromAuthentication(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return null; // Allow unauthenticated access, just won’t set isFollowed
        }
        String username = authentication.getName();
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username))
                .getId();
    }
}