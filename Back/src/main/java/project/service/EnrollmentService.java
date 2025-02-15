package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.dto.EnrollmentDTO;
import project.models.*;
import project.repository.EnrollmentRepository;
import project.repository.UserRepository;
import project.repository.CourseRepository;
import project.exception.ResourceNotFoundException;

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

    public EnrollmentDTO enrollStudentInCourse(Long userId, Long courseId) {
        UserEntity student = userRepository.findById(userId.intValue())  // Convert Long to Integer
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        // Check if student is already enrolled
        if (enrollmentRepository.findByStudentAndCourse(student, course).isPresent()) {
            throw new IllegalStateException("Student is already enrolled in this course");
        }

        Enrollment enrollment = new Enrollment();
        enrollment.setStudent(student);
        enrollment.setCourse(course);
        enrollment.setStatus(EnrollmentStatus.ONGOING);
        enrollment.setProgressPercentage(0);
        enrollment.setEnrollmentDate(LocalDateTime.now());
        enrollment.setLastAccessedDate(LocalDateTime.now());

        enrollment = enrollmentRepository.save(enrollment);
        return convertToDTO(enrollment);
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

    public void unenrollStudentFromCourse(Long userId, Long courseId) {
        // Convert userId to Integer
        UserEntity student = userRepository.findById(userId.intValue())
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        // Course assumed to use Long, so no conversion needed
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        Enrollment enrollment = enrollmentRepository.findByStudentAndCourse(student, course)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found"));

        // Add any additional checks for unenrollment restrictions here

        enrollmentRepository.delete(enrollment);
    }

    public List<EnrollmentDTO> getEnrolledCourses(Long userId) {
        UserEntity student = userRepository.findById(userId.intValue())  // Convert Long to Integer
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        return enrollmentRepository.findByStudent(student).stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }

    public void updateEnrollmentProgress(Long enrollmentId, int progressPercentage, Long userId) {
        Enrollment enrollment = enrollmentRepository.findById(enrollmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found"));

        // Check if the user is the owner of this enrollment
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
}
