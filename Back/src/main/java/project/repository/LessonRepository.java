package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Lesson;

public interface LessonRepository extends JpaRepository<Lesson, Long> {
}

