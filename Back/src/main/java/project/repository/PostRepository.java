package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import project.models.PostEntity;

@Repository
public interface PostRepository extends JpaRepository<PostEntity,Long> {
}
