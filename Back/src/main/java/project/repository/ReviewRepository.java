package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.Review;

public interface ReviewRepository extends JpaRepository<Review, Long> {
    // Custom query methods if needed
}

