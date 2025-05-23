package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import project.models.Instructor;
import project.models.Session;

import java.util.List;

@Repository
public interface SessionRepository extends JpaRepository<Session, Long> {
    List<Session> findAll();
    List<Session> findByInstructor(Instructor instructor);
}