package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import project.models.Instructor;
import project.models.InstructorStatus;
import project.models.UserEntity;

import java.util.List;
import java.util.Optional;

@Repository
public interface InstructorRepository extends JpaRepository<Instructor, Long> {
    List<Instructor> findByStatus(InstructorStatus status);
    Optional<Instructor> findByUser(UserEntity user);
}

