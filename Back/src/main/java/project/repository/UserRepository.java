package project.repository;
import org.apache.catalina.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
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
    Page<UserEntity> findByUserRole_UserRoleName(UserRoleName userRoleName, Pageable pageable);

    @Query("SELECT u FROM UserEntity u WHERE u.userRole.userRoleName = :role")
    List<UserEntity> findByRole(UserRoleName role, Pageable pageable);
}
