package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import project.dto.EnrollmentDTO;
import project.models.UserEntity;
import project.repository.UserRepository;
import project.service.EnrollmentService;

import java.util.List;

@RestController
@RequestMapping("/api/enrollments")
public class EnrollmentController {

    @Autowired
    private EnrollmentService enrollmentService;

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/enroll/{courseId}")
    public ResponseEntity<EnrollmentDTO> enrollInCourse(@PathVariable Long courseId, Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        EnrollmentDTO enrollmentDTO = enrollmentService.enrollStudentInCourse(userId, courseId);
        return new ResponseEntity<>(enrollmentDTO, HttpStatus.CREATED);
    }

    @DeleteMapping("/unenroll/{courseId}")
    public ResponseEntity<Void> unenrollFromCourse(@PathVariable Long courseId, Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        enrollmentService.unenrollStudentFromCourse(userId, courseId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/my-courses")
    public ResponseEntity<List<EnrollmentDTO>> getEnrolledCourses(Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        List<EnrollmentDTO> enrollments = enrollmentService.getEnrolledCourses(userId);
        return ResponseEntity.ok(enrollments);
    }

    @PutMapping("/{enrollmentId}/progress")
    public ResponseEntity<Void> updateProgress(@PathVariable Long enrollmentId,
                                               @RequestParam int progressPercentage,
                                               Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        enrollmentService.updateEnrollmentProgress(enrollmentId, progressPercentage, userId);
        return ResponseEntity.ok().build();
    }

    private Long getUserIdFromAuthentication(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalStateException("User is not authenticated");
        }
        Object principal = authentication.getPrincipal();
        if (!(principal instanceof UserDetails)) {
            throw new IllegalStateException("Authentication principal is not of type UserDetails");
        }
        UserDetails userDetails = (UserDetails) principal;
        String username = userDetails.getUsername();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));
        return (long) user.getId();
    }
}
