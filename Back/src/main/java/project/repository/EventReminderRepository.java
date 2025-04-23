
package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.EventReminder;
import org.springframework.data.jpa.repository.Query;

public interface EventReminderRepository extends JpaRepository<EventReminder, Long> {
    boolean existsByEventId(Long eventId);

    @Query("SELECT COUNT(r) > 0 FROM EventReminder r WHERE r.eventId = :eventId AND r.hoursBefore = :hoursBefore")
    boolean existsByEventIdAndHoursBefore(Long eventId, Integer hoursBefore);
}