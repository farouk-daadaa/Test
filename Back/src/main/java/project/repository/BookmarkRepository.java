package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Bookmark;
import project.models.Course;
import project.models.UserEntity;

import java.util.List;
import java.util.Optional;

public interface BookmarkRepository extends JpaRepository<Bookmark, Long> {
    List<Bookmark> findByUser(UserEntity user);
    Optional<Bookmark> findByUserAndCourse(UserEntity user, Course course);
    boolean existsByUserAndCourse(UserEntity user, Course course);
    void deleteByUser(UserEntity user);
}