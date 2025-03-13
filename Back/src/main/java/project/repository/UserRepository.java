package project.repository;
import org.apache.catalina.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import project.models.Instructor;
import project.models.UserEntity;
import project.models.UserRoleName;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<UserEntity,Long > {

    Optional<UserEntity> findByUsername(String username);
    Boolean existsByUsername(String username);
    Boolean existsByEmail(String email);
    Optional<UserEntity> findByEmail(String email);
    List<UserEntity> findByUserRole_UserRoleName(UserRoleName userRoleName);

    List<UserEntity> findByFollowedInstructors(Instructor instructor);
    Optional<UserEntity> findByIdAndFollowedInstructors(Long userId, Instructor instructor);
    boolean existsByIdAndFollowedInstructors(Long userId, Instructor instructor);


}
