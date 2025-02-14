package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.models.Course;
import project.service.CourseService;

import javax.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/courses")
public class CourseController {

    @Autowired
    private CourseService courseService;

    @PostMapping
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal)")
    public ResponseEntity<Course> createCourse(@Valid @RequestBody Course course, @RequestParam Long categoryId, Authentication authentication) {
        Course createdCourse = courseService.createCourse(course, categoryId, authentication.getName());
        return new ResponseEntity<>(createdCourse, HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #id)")
    public ResponseEntity<Course> updateCourse(@PathVariable Long id, @Valid @RequestBody Course course, @RequestParam(required = false) Long categoryId) {
        Course updatedCourse = courseService.updateCourse(id, course, categoryId);
        return ResponseEntity.ok(updatedCourse);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #id)")
    public ResponseEntity<Void> deleteCourse(@PathVariable Long id) {
        courseService.deleteCourse(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Course> getCourse(@PathVariable Long id) {
        Course course = courseService.getCourseById(id);
        return ResponseEntity.ok(course);
    }

    @GetMapping
    public ResponseEntity<List<Course>> getAllCourses() {
        List<Course> courses = courseService.getAllCourses();
        return ResponseEntity.ok(courses);
    }
}