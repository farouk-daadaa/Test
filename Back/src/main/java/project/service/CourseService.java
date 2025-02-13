package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.Course;
import project.models.Instructor;
import project.models.UserEntity;
import project.repository.CourseRepository;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import project.exception.ResourceNotFoundException;

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

    public Course createCourse(Course course, String username) {
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Instructor instructor = instructorRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("Instructor not found"));

        // Set default values
        course.setInstructor(instructor);
        course.setLastUpdate(LocalDate.now());
        course.setRating(0.0);
        course.setTotalReviews(0);
        course.setTotalStudents(0);

        return courseRepository.save(course);
    }

    public Course updateCourse(Long id, Course courseDetails) {
        Course course = getCourseById(id);
        course.setTitle(courseDetails.getTitle());
        course.setDescription(courseDetails.getDescription());
        course.setPrice(courseDetails.getPrice());
        course.setLevel(courseDetails.getLevel());
        course.setLanguage(courseDetails.getLanguage());
        course.setImageUrl(courseDetails.getImageUrl());
        course.setCategory(courseDetails.getCategory());
        course.setLastUpdate(LocalDate.now());

        return courseRepository.save(course);
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