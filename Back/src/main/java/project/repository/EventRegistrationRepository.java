package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import project.models.Event;
import project.models.EventRegistration;
import project.models.UserEntity;

import java.util.List;
import java.util.Optional;

@Repository
public interface EventRegistrationRepository extends JpaRepository<EventRegistration, Long> {
    boolean existsByEventAndStudent(Event event, UserEntity student);
    Optional<EventRegistration> findByEventAndStudent(Event event, UserEntity student);
    List<EventRegistration> findByStudent(UserEntity student);

    @Query("SELECT r FROM EventRegistration r JOIN FETCH r.student WHERE r.event = :event")
    List<EventRegistration> findAllByEvent(Event event);

    void deleteByEventAndStudent(Event event, UserEntity student);
}