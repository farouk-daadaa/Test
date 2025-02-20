package project.repository;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import project.models.Image;

import java.util.Optional;

@Repository
public interface ImageRepository extends JpaRepository<Image,Long > {


    Optional<Image> findByUserEntityId(Long idUser);
}
