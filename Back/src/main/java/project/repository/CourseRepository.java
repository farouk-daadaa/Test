package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Course;

import java.util.List;

public interface CourseRepository extends JpaRepository<Course, Long> {

    List<Course> findByInstructorId(Long instructorId);
    void deleteByInstructorId(Long instructorId);
}

