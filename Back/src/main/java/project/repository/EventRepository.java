package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import project.models.Event;

@Repository
public interface EventRepository extends JpaRepository<Event, Long> {
    Page<Event> findAll(Pageable pageable); // Added for pagination

    @Query("SELECT e FROM Event e WHERE :status IS NULL OR e.status = :status")
    Page<Event> findByStatus(Event.EventStatus status, Pageable pageable);
}