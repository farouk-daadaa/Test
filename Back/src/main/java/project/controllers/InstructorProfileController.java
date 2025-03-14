package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.CourseDTO;
import project.dto.InstructorProfileDTO;
import project.models.Instructor;
import project.models.UserEntity;
import project.repository.InstructorRepository;
import project.repository.UserRepository;

import java.util.List;
import java.util.stream.Collectors;

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
        instructor.getFollowers().size();
        Long currentUserId = authentication != null ? getUserIdFromAuthentication(authentication) : null;
        InstructorProfileDTO profileDTO = InstructorProfileDTO.fromEntity(instructor, currentUserId);
        return ResponseEntity.ok(profileDTO);
    }

    @GetMapping(value = "/{instructorId}/courses", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<List<CourseDTO>> getInstructorCourses(@PathVariable Long instructorId) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found with id: " + instructorId));
        List<CourseDTO> courses = instructor.getCourses().stream()
                .map(CourseDTO::fromEntity)
                .collect(Collectors.toList());
        return ResponseEntity.ok(courses);
    }

    private Long getUserIdFromAuthentication(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            System.out.println("Authentication is null or not authenticated");
            return null;
        }
        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));
        System.out.println("Authenticated user: " + username + ", ID: " + user.getId());
        return user.getId();
    }

    @GetMapping("/username/{username}/id")
    public ResponseEntity<Integer> getInstructorIdByUsername(@PathVariable String username) {
        Instructor instructor = instructorRepository.findByUserUsername(username)
                .orElseThrow(() -> new IllegalStateException("Instructor not found with username: " + username));
        return ResponseEntity.ok(instructor.getId().intValue());
    }

    @GetMapping("/{instructorId}/user-id")
    public ResponseEntity<Integer> getUserIdByInstructorId(@PathVariable Long instructorId) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found with id: " + instructorId));
        return ResponseEntity.ok(instructor.getUser().getId().intValue());
    }

    private String profileDTOToString(InstructorProfileDTO dto) {
        return "InstructorProfileDTO{username='" + dto.getUsername() + "', " +
                "followersCount=" + dto.getFollowersCount() + ", " +
                "isFollowed=" + dto.isFollowed() + "}";
    }
}