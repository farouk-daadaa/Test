package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Enrollment;
import project.models.UserEntity;
import project.models.Course;

import java.util.List;
import java.util.Optional;

public interface EnrollmentRepository extends JpaRepository<Enrollment, Long> {
    List<Enrollment> findByStudent(UserEntity student);
    Optional<Enrollment> findByStudentAndCourse(UserEntity student, Course course);
    boolean existsByIdAndStudentId(Long id, Long studentId);
    Optional<Enrollment> findByCourseAndStudent(Course course, UserEntity student);

}