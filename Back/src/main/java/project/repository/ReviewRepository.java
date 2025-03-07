package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Course;
import project.models.Review;
import project.models.UserEntity;

import java.util.List;

public interface ReviewRepository extends JpaRepository<Review, Long> {
    List<Review> findByCourse(Course course);
    List<Review> findByCourseOrderByCreatedAtDesc(Course course);
    List<Review> findByCourseOrderByRatingDesc(Course course);
    void deleteByUser(UserEntity user);
}