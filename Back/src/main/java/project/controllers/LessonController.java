package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import project.dto.LessonDTO;
import project.service.LessonService;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/courses/{courseId}/lessons")
public class LessonController {

    @Autowired
    private LessonService lessonService;

    @GetMapping("/{lessonId}")
    public ResponseEntity<LessonDTO> getLesson(@PathVariable Long courseId, @PathVariable Long lessonId) {
        LessonDTO lesson = lessonService.getLessonById(lessonId);
        return ResponseEntity.ok(lesson);
    }

    @GetMapping
    public ResponseEntity<List<LessonDTO>> getAllLessonsForCourse(@PathVariable Long courseId) {
        List<LessonDTO> lessons = lessonService.getAllLessonsByCourseId(courseId);
        return ResponseEntity.ok(lessons);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<LessonDTO> addLesson(
            @PathVariable Long courseId,
            @RequestParam("title") String title,
            @RequestParam(value = "video", required = false) MultipartFile video) throws IOException {
        LessonDTO newLesson = lessonService.addLesson(courseId, title, video);
        return ResponseEntity.ok(newLesson);
    }

    @PutMapping(value = "/{lessonId}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<LessonDTO> updateLesson(
            @PathVariable Long courseId,
            @PathVariable Long lessonId,
            @RequestParam("title") String title,
            @RequestParam(value = "video", required = false) MultipartFile video) throws IOException {
        LessonDTO updatedLesson = lessonService.updateLesson(lessonId, title, video);
        return ResponseEntity.ok(updatedLesson);
    }

    @DeleteMapping("/{lessonId}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<Void> deleteLesson(@PathVariable Long courseId, @PathVariable Long lessonId) {
        lessonService.deleteLesson(lessonId);
        return ResponseEntity.noContent().build();
    }
}