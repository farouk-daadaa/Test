package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.dto.EnrollmentDTO;
import project.exception.ResourceNotFoundException;
import project.models.Course;
import project.models.Enrollment;
import project.models.EnrollmentStatus;
import project.models.Lesson;
import project.models.LessonProgress;
import project.models.UserEntity;
import project.repository.CourseRepository;
import project.repository.EnrollmentRepository;
import project.repository.LessonProgressRepository;
import project.repository.UserRepository;

import javax.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class EnrollmentService {

    @Autowired
    private EnrollmentRepository enrollmentRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private LessonProgressRepository lessonProgressRepository;

    @Transactional
    public EnrollmentDTO enrollStudentInCourse(Long userId, Long courseId) {
        UserEntity student = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        // Check if the student is already enrolled in the course
        if (enrollmentRepository.findByStudentAndCourse(student, course).isPresent()) {
            throw new IllegalStateException("Student is already enrolled in this course");
        }

        // Create and save the Enrollment
        Enrollment enrollment = new Enrollment();
        enrollment.setStudent(student);
        enrollment.setCourse(course);
        enrollment.setStatus(EnrollmentStatus.ONGOING);
        enrollment.setProgressPercentage(0);
        enrollment.setEnrollmentDate(LocalDateTime.now());
        enrollment.setLastAccessedDate(LocalDateTime.now());
        enrollment = enrollmentRepository.save(enrollment);

        // Initialize LessonProgress for each lesson in the course
        for (Lesson lesson : course.getLessons()) {
            LessonProgress lessonProgress = new LessonProgress();
            lessonProgress.setEnrollment(enrollment);
            lessonProgress.setLesson(lesson);
            lessonProgress.setStatus(LessonProgress.LessonStatus.PENDING);
            lessonProgressRepository.save(lessonProgress);
        }

        // Increment the total students count
        course.setTotalStudents(course.getTotalStudents() + 1);
        courseRepository.save(course);

        return convertToDTO(enrollment);
    }

    @Transactional
    public void unenrollStudentFromCourse(Long userId, Long courseId) {
        UserEntity student = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        // Find the enrollment
        Enrollment enrollment = enrollmentRepository.findByStudentAndCourse(student, course)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found"));

        // Delete the enrollment
        enrollmentRepository.delete(enrollment);

        // Decrement the total students count
        int currentStudents = course.getTotalStudents();
        course.setTotalStudents(Math.max(0, currentStudents - 1)); // Ensure it doesn't go below 0
        courseRepository.save(course);
    }

    public List<EnrollmentDTO> getEnrolledCourses(Long userId) {
        UserEntity student = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        return enrollmentRepository.findByStudent(student)
                .stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public void updateEnrollmentProgress(Long enrollmentId, int progressPercentage, Long userId) {
        Enrollment enrollment = enrollmentRepository.findById(enrollmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found"));

        if (enrollment.getStudent().getId() != userId.intValue()) {
            throw new IllegalStateException("User is not authorized to update this enrollment");
        }

        enrollment.setProgressPercentage(progressPercentage);
        enrollment.setLastAccessedDate(LocalDateTime.now());

        if (progressPercentage == 100) {
            enrollment.setStatus(EnrollmentStatus.COMPLETED);
        }

        enrollmentRepository.save(enrollment);
    }

    private EnrollmentDTO convertToDTO(Enrollment enrollment) {
        EnrollmentDTO dto = new EnrollmentDTO();
        dto.setId(enrollment.getId());
        dto.setCourseId(enrollment.getCourse().getId());
        dto.setCourseTitle(enrollment.getCourse().getTitle());
        dto.setCourseDescription(enrollment.getCourse().getDescription());
        dto.setStatus(enrollment.getStatus());
        dto.setProgressPercentage(enrollment.getProgressPercentage());
        dto.setEnrollmentDate(enrollment.getEnrollmentDate());
        dto.setLastAccessedDate(enrollment.getLastAccessedDate());
        return dto;
    }
}
