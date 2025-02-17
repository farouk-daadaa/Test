package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import project.dto.LessonProgressDTO;
import project.models.UserEntity;
import project.repository.UserRepository;
import project.service.LessonProgressService;

@RestController
@RequestMapping("/api/lesson-progress")
public class LessonProgressController {

    @Autowired
    private LessonProgressService lessonProgressService;

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/{enrollmentId}/complete/{lessonId}")
    public ResponseEntity<LessonProgressDTO> markLessonAsCompleted(
            @PathVariable Long enrollmentId,
            @PathVariable Long lessonId) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        UserEntity currentUser = userRepository.findByUsername(authentication.getName())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!lessonProgressService.isUserEnrolledInCourse(Long.valueOf(currentUser.getId()), enrollmentId)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        LessonProgressDTO lessonProgress = lessonProgressService.markLessonAsCompleted(enrollmentId, lessonId);
        return ResponseEntity.ok(lessonProgress);
    }

    @GetMapping("/{enrollmentId}/progress")
    public ResponseEntity<Integer> getCourseProgress(@PathVariable Long enrollmentId) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        UserEntity currentUser = userRepository.findByUsername(authentication.getName())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!lessonProgressService.isUserEnrolledInCourse(Long.valueOf(currentUser.getId()), enrollmentId)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        int progress = lessonProgressService.getCourseProgress(enrollmentId);
        return ResponseEntity.ok(progress);
    }
}