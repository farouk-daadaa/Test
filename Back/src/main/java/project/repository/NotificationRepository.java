package project.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import project.models.Notification;
import project.models.UserEntity;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByUserId(Long userId);
    List<Notification> findByUserIdAndIsRead(Long userId, boolean isRead);

    @Query("SELECT n FROM Notification n WHERE n.expiresAt < :currentTime")
    List<Notification> findByExpiresAtBefore(LocalDateTime currentTime, Pageable pageable);

    @Modifying
    @Query("DELETE FROM Notification n WHERE n.id IN :ids")
    int deleteByIds(List<Long> ids);

    @Modifying
    @Query("DELETE FROM Notification n WHERE n.id = :notificationId AND n.user.id = :userId")
    int deleteByIdAndUserId(Long notificationId, Long userId);

    @Modifying
    @Query("UPDATE Notification n SET n.isRead = true WHERE n.user.id = :userId AND n.isRead = false AND n.expiresAt > :currentTime")
    int markAllAsReadForUser(Long userId, LocalDateTime currentTime);
}