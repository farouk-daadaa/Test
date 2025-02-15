package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.*;
import project.repository.CourseCategoryRepository;
import project.repository.CourseRepository;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import project.exception.ResourceNotFoundException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

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

    public Course createCourse(Course course, Long categoryId, String username) {
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Instructor instructor = instructorRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("Instructor not found"));

        CourseCategory category = courseCategoryRepository.findById(categoryId)
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + categoryId));

        course.setInstructor(instructor);
        course.setCategory(category);
        course.setLastUpdate(LocalDate.now());
        course.setRating(0.0);
        course.setTotalReviews(0);
        course.setTotalStudents(0);

        // Handle pricing type and price
        handlePricingAndPrice(course);

        return courseRepository.save(course);
    }

    public Course updateCourse(Long id, Course courseDetails, Long categoryId) {
        Course course = getCourseById(id);

        // Update basic details
        course.setTitle(courseDetails.getTitle());
        course.setDescription(courseDetails.getDescription());
        course.setLevel(courseDetails.getLevel());
        course.setLanguage(courseDetails.getLanguage());
        course.setImageUrl(courseDetails.getImageUrl());
        course.setLastUpdate(LocalDate.now());

        // Update pricing type and price
        course.setPricingType(courseDetails.getPricingType());
        course.setPrice(courseDetails.getPrice());
        handlePricingAndPrice(course);

        if (categoryId != null) {
            CourseCategory category = courseCategoryRepository.findById(categoryId)
                    .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + categoryId));
            course.setCategory(category);
        }

        return courseRepository.save(course);
    }

    private void handlePricingAndPrice(Course course) {
        // Set default pricing type if not specified
        if (course.getPricingType() == null) {
            course.setPricingType(PricingType.PAID);
        }

        // Handle price based on pricing type
        if (course.getPricingType() == PricingType.FREE) {
            course.setPrice(BigDecimal.ZERO);
        } else if (course.getPrice() == null || course.getPrice().compareTo(BigDecimal.ZERO) < 0) {
            // Set default price for paid courses if price is null or negative
            course.setPrice(BigDecimal.ZERO);
        }
    }

    public void deleteCourse(Long id) {
        Course course = getCourseById(id);
        courseRepository.delete(course);
    }

    public Course getCourseById(Long id) {
        return courseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + id));
    }

    public List<Course> getAllCourses() {
        return courseRepository.findAll();
    }
}