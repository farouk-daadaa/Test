package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import project.dto.CourseDTO;
import project.models.Instructor;
import project.models.UserEntity;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import project.service.CourseService;

import javax.validation.Valid;
import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/courses")
public class CourseController {

    @Autowired
    private CourseService courseService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InstructorRepository instructorRepository;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal)")
    public ResponseEntity<CourseDTO> createCourse(
            @RequestPart("course") @Valid CourseDTO courseDTO,
            @RequestPart(value = "image", required = false) MultipartFile image,
            @RequestParam Long categoryId,
            Authentication authentication) throws IOException {
        CourseDTO createdCourse = courseService.createCourse(courseDTO, categoryId, authentication.getName(), image);
        return new ResponseEntity<>(createdCourse, HttpStatus.CREATED);
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal) and @userSecurity.isOwnerOfCourse(authentication.principal, #id)")
    public ResponseEntity<CourseDTO> updateCourse(
            @PathVariable Long id,
            @RequestPart("course") @Valid CourseDTO courseDTO,
            @RequestPart(value = "image", required = false) MultipartFile image,
            @RequestParam(required = false) Long categoryId) throws IOException {
        CourseDTO updatedCourse = courseService.updateCourse(id, courseDTO, categoryId, image);
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

    @GetMapping("/my")
    @PreAuthorize("hasRole('INSTRUCTOR') and @userSecurity.isApprovedInstructor(authentication.principal)")
    public ResponseEntity<List<CourseDTO>> getMyCourses(Authentication authentication) {
        UserEntity userEntity = userRepository.findByUsername(authentication.getName())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Instructor instructor = instructorRepository.findByUser(userEntity)
                .orElseThrow(() -> new RuntimeException("Instructor not found"));
        List<CourseDTO> myCourses = courseService.getCoursesByInstructorId(instructor.getId());
        return ResponseEntity.ok(myCourses);
    }

}