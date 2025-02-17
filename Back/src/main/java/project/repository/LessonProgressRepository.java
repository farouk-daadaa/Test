package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Enrollment;
import project.models.Lesson;
import project.models.LessonProgress;

import java.util.List;
import java.util.Optional;

public interface LessonProgressRepository extends JpaRepository<LessonProgress, Long> {
    Optional<LessonProgress> findByEnrollmentAndLesson(Enrollment enrollment, Lesson lesson);
    List<LessonProgress> findByEnrollment(Enrollment enrollment);
}