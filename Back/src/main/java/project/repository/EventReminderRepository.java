
package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import project.models.EventReminder;

public interface EventReminderRepository extends JpaRepository<EventReminder, Long> {
    boolean existsByEventId(Long eventId);
}