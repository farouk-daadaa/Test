package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.CourseCategory;

public interface CourseCategoryRepository extends JpaRepository<CourseCategory, Long> {
}

