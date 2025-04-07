package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import project.models.Instructor;
import project.models.InstructorStatus;
import project.models.UserEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Optional;

@Repository
public interface InstructorRepository extends JpaRepository<Instructor, Long> {
    List<Instructor> findByStatus(InstructorStatus status);

    Optional<Instructor> findByUser(UserEntity user);

    Optional<Instructor> findByUserUsername(String username);

    @Query("SELECT u FROM UserEntity u JOIN u.followedInstructors i WHERE i.id = :instructorId")
    Page<UserEntity> findFollowersById(@Param("instructorId") Long instructorId, Pageable pageable);
}

