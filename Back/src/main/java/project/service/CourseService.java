package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.dto.CourseDTO;
import project.models.*;
import project.repository.CourseCategoryRepository;
import project.repository.CourseRepository;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import project.exception.ResourceNotFoundException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class CourseService {

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private CourseCategoryRepository courseCategoryRepository;

    public CourseDTO createCourse(CourseDTO courseDTO, Long categoryId, String username) {
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Instructor instructor = instructorRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("Instructor not found"));

        CourseCategory category = courseCategoryRepository.findById(categoryId)
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + categoryId));

        Course course = new Course();
        course.setTitle(courseDTO.getTitle());
        course.setDescription(courseDTO.getDescription());
        course.setPrice(courseDTO.getPrice());
        course.setPricingType(courseDTO.getPricingType());
        course.setImageUrl(courseDTO.getImageUrl());
        course.setLevel(courseDTO.getLevel());  // Now using CourseLevel enum directly
        course.setLanguage(courseDTO.getLanguage());  // Now using CourseLanguage enum directly
        course.setInstructor(instructor);
        course.setCategory(category);
        course.setLastUpdate(LocalDate.now());
        course.setRating(0.0);
        course.setTotalReviews(0);
        course.setTotalStudents(0);

        handlePricingAndPrice(course);

        Course savedCourse = courseRepository.save(course);
        return CourseDTO.fromEntity(savedCourse);
    }

    public CourseDTO updateCourse(Long id, CourseDTO courseDTO, Long categoryId) {
        Course course = getCourseEntityById(id);  // Changed to use the correct method

        course.setTitle(courseDTO.getTitle());
        course.setDescription(courseDTO.getDescription());
        course.setLevel(courseDTO.getLevel());  // Now using CourseLevel enum directly
        course.setLanguage(courseDTO.getLanguage());  // Now using CourseLanguage enum directly
        course.setImageUrl(courseDTO.getImageUrl());
        course.setLastUpdate(LocalDate.now());
        course.setPricingType(courseDTO.getPricingType());
        course.setPrice(courseDTO.getPrice());

        handlePricingAndPrice(course);

        if (categoryId != null) {
            CourseCategory category = courseCategoryRepository.findById(categoryId)
                    .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + categoryId));
            course.setCategory(category);
        }

        Course updatedCourse = courseRepository.save(course);
        return CourseDTO.fromEntity(updatedCourse);
    }

    private void handlePricingAndPrice(Course course) {
        if (course.getPricingType() == null) {
            course.setPricingType(PricingType.PAID);
        }

        if (course.getPricingType() == PricingType.FREE) {
            course.setPrice(BigDecimal.ZERO);
        } else if (course.getPrice() == null || course.getPrice().compareTo(BigDecimal.ZERO) < 0) {
            course.setPrice(BigDecimal.ZERO);
        }
    }

    public void deleteCourse(Long id) {
        Course course = getCourseEntityById(id);
        courseRepository.delete(course);
    }

    public CourseDTO getCourseById(Long id) {
        Course course = courseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + id));
        return CourseDTO.fromEntity(course);
    }

    public List<CourseDTO> getAllCourses() {
        return courseRepository.findAll().stream()
                .map(CourseDTO::fromEntity)
                .collect(Collectors.toList());
    }

    // This method is used internally and still returns the Course entity
    private Course getCourseEntityById(Long id) {
        return courseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + id));
    }
}