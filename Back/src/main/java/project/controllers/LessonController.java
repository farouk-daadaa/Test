package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import project.models.Lesson;
import project.service.LessonService;

import javax.validation.Valid;

@RestController
@RequestMapping("/api/courses/{courseId}/lessons")
public class LessonController {

    @Autowired
    private LessonService lessonService;

    @PostMapping
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<Lesson> addLesson(@PathVariable Long courseId, @Valid @RequestBody Lesson lesson) {
        Lesson createdLesson = lessonService.addLessonToCourse(courseId, lesson);
        return new ResponseEntity<>(createdLesson, HttpStatus.CREATED);
    }

    @PutMapping("/{lessonId}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<Lesson> updateLesson(@PathVariable Long courseId, @PathVariable Long lessonId, @Valid @RequestBody Lesson lesson) {
        Lesson updatedLesson = lessonService.updateLesson(courseId, lessonId, lesson);
        return ResponseEntity.ok(updatedLesson);
    }

    @DeleteMapping("/{lessonId}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #courseId)")
    public ResponseEntity<Void> deleteLesson(@PathVariable Long courseId, @PathVariable Long lessonId) {
        lessonService.deleteLesson(courseId, lessonId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{lessonId}")
    public ResponseEntity<Lesson> getLesson(@PathVariable Long courseId, @PathVariable Long lessonId) {
        Lesson lesson = lessonService.getLessonById(courseId, lessonId);
        return ResponseEntity.ok(lesson);
    }
}

