package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import project.models.Event;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface EventRepository extends JpaRepository<Event, Long> {
    Page<Event> findAll(Pageable pageable);

    @Query("SELECT e FROM Event e WHERE :status IS NULL OR e.status = :status")
    Page<Event> findByStatus(Event.EventStatus status, Pageable pageable);

    @Query("SELECT e FROM Event e WHERE e.startDateTime BETWEEN :start AND :end")
    List<Event> findByStartDateTimeBetween(LocalDateTime start, LocalDateTime end);

    @Query("SELECT COUNT(r) FROM EventRegistration r WHERE r.event.id = :eventId")
    int countRegistrationsByEventId(Long eventId);
}