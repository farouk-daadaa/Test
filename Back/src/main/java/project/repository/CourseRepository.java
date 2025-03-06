package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Course;

import java.util.List;

public interface CourseRepository extends JpaRepository<Course, Long> {

    List<Course> findByInstructorId(Long instructorId);
    // You can add custom query methods here if needed
}

