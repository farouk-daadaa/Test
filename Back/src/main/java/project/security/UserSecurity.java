package project.security;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Component;
import project.models.Course;
import project.models.Instructor;
import project.models.InstructorStatus;
import project.models.UserEntity;
import project.repository.CourseRepository;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import org.springframework.security.core.userdetails.User;

@Component("userSecurity")
public class UserSecurity {

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private UserRepository userRepository;

    public boolean isApprovedInstructor(org.springframework.security.core.userdetails.User user) {
        // We need to fetch the UserEntity based on the Spring Security User
        UserEntity userEntity = userRepository.findByUsername(user.getUsername())
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));

        return instructorRepository.findByUser(userEntity)
                .map(instructor -> instructor.getStatus() == InstructorStatus.APPROVED)
                .orElse(false);
    }

    public boolean isOwnerOfCourse(User user, Long courseId) {
        UserEntity userEntity = userRepository.findByUsername(user.getUsername())
                .orElseThrow(() -> new RuntimeException("User not found"));
        Instructor instructor = instructorRepository.findByUser(userEntity)
                .orElseThrow(() -> new RuntimeException("Instructor not found"));
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new RuntimeException("Course not found"));
        return course.getInstructor().getId().equals(instructor.getId());
    }
}

