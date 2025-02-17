package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.CourseDTO;
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
    public ResponseEntity<CourseDTO> createCourse(@Valid @RequestBody CourseDTO courseDTO, @RequestParam Long categoryId, Authentication authentication) {
        CourseDTO createdCourse = courseService.createCourse(courseDTO, categoryId, authentication.getName());
        return new ResponseEntity<>(createdCourse, HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #id)")
    public ResponseEntity<CourseDTO> updateCourse(@PathVariable Long id, @Valid @RequestBody CourseDTO courseDTO, @RequestParam(required = false) Long categoryId) {
        CourseDTO updatedCourse = courseService.updateCourse(id, courseDTO, categoryId);
        return ResponseEntity.ok(updatedCourse);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #id)")
    public ResponseEntity<Void> deleteCourse(@PathVariable Long id) {
        courseService.deleteCourse(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}")
    public ResponseEntity<CourseDTO> getCourse(@PathVariable Long id) {
        CourseDTO course = courseService.getCourseById(id);
        return ResponseEntity.ok(course);
    }

    @GetMapping
    public ResponseEntity<List<CourseDTO>> getAllCourses() {
        List<CourseDTO> courses = courseService.getAllCourses();
        return ResponseEntity.ok(courses);
    }
}