package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import project.models.Lesson;
import project.service.LessonService;

import javax.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/courses/{courseId}/lessons")
public class LessonController {

    @Autowired
    private LessonService lessonService;

    @GetMapping("/{lessonId}")
    public ResponseEntity<Lesson> getLesson(@PathVariable Long courseId, @PathVariable Long lessonId) {
        Lesson lesson = lessonService.getLessonById(lessonId);
        return ResponseEntity.ok(lesson);
    }

    @GetMapping
    public ResponseEntity<List<Lesson>> getAllLessonsForCourse(@PathVariable Long courseId) {
        List<Lesson> lessons = lessonService.getAllLessonsByCourseId(courseId);
        return ResponseEntity.ok(lessons);
    }

    @PostMapping
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<Lesson> addLesson(@PathVariable Long courseId, @Valid @RequestBody Lesson lesson) {
        Lesson newLesson = lessonService.addLesson(courseId, lesson);
        return ResponseEntity.ok(newLesson);
    }

    @PutMapping("/{lessonId}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<Lesson> updateLesson(@PathVariable Long courseId, @PathVariable Long lessonId, @Valid @RequestBody Lesson lessonDetails) {
        Lesson updatedLesson = lessonService.updateLesson(lessonId, lessonDetails);
        return ResponseEntity.ok(updatedLesson);
    }

    @DeleteMapping("/{lessonId}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<Void> deleteLesson(@PathVariable Long courseId, @PathVariable Long lessonId) {
        lessonService.deleteLesson(lessonId);
        return ResponseEntity.noContent().build();
    }
}