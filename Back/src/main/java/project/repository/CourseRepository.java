package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Course;

public interface CourseRepository extends JpaRepository<Course, Long> {
    // You can add custom query methods here if needed
}

