package project.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import project.dto.NotificationDTO;
import project.models.Notification;
import project.models.UserEntity;
import project.models.UserRoleName;
import project.repository.NotificationRepository;
import project.repository.UserRepository;

import javax.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class NotificationService {

    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Value("${notification.expiry-days:30}")
    private int expiryDays; // Configurable expiry period

    @Transactional
    public Notification createNotification(Long userId, String title, String message, Notification.NotificationType type) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found with id: " + userId));

        Notification notification = new Notification();
        notification.setUser(user);
        notification.setTitle(title);
        notification.setMessage(message);
        notification.setType(type);
        notification.setExpiresAt(LocalDateTime.now().plusDays(expiryDays)); // Set expiry based on configurable value
        Notification savedNotification = notificationRepository.save(notification);

        // Send real-time notification via WebSocket
        NotificationDTO dto = NotificationDTO.fromEntity(savedNotification);
        logger.info("Sending WebSocket notification to /topic/notifications/{}: {}", userId, dto);
        try {
            messagingTemplate.convertAndSend("/topic/notifications/" + userId, dto);
            logger.info("Successfully sent WebSocket notification to /topic/notifications/{}", userId);
        } catch (Exception e) {
            logger.error("Failed to send WebSocket notification to /topic/notifications/{}: {}", userId, e.getMessage(), e);
        }

        return savedNotification;
    }

    @Transactional
    public void createNotificationsWithPagination(List<Long> userIds, String title, String message, Notification.NotificationType type, UserRoleName roleFilter) {
        logger.info("Creating notifications for {} users (with pagination) with role {}", userIds.size(), roleFilter);

        if (!userIds.isEmpty()) {
            int pageSize = 100;
            for (int i = 0; i < userIds.size(); i += pageSize) {
                List<Long> batchUserIds = userIds.subList(i, Math.min(i + pageSize, userIds.size()));
                List<UserEntity> users = userRepository.findAllById(batchUserIds).stream()
                        .filter(user -> user.getUserRole() != null && user.getUserRole().getUserRoleName() == roleFilter)
                        .collect(Collectors.toList());
                createNotificationBatch(users, title, message, type);
            }
        } else {
            int pageSize = 100;
            Pageable pageable = PageRequest.of(0, pageSize);
            Page<UserEntity> userPage;

            do {
                userPage = userRepository.findByUserRole_UserRoleName(roleFilter, pageable);
                List<UserEntity> users = userPage.getContent();
                createNotificationBatch(users, title, message, type);
                pageable = pageable.next();
            } while (userPage.hasNext());
        }
    }

    // Overload for backward compatibility (default to USER role)
    @Transactional
    public void createNotificationsWithPagination(List<Long> userIds, String title, String message, Notification.NotificationType type) {
        createNotificationsWithPagination(userIds, title, message, type, UserRoleName.USER);
    }

    private void createNotificationBatch(List<UserEntity> users, String title, String message, Notification.NotificationType type) {
        if (users.isEmpty()) {
            logger.warn("No users in batch to notify");
            return;
        }

        List<Notification> notifications = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime expiresAt = now.plusDays(expiryDays); // Calculate expiry once for the batch
        for (UserEntity user : users) {
            Notification notification = new Notification();
            notification.setUser(user);
            notification.setTitle(title);
            notification.setMessage(message);
            notification.setType(type);
            notification.setExpiresAt(expiresAt); // Set expiry for all notifications in the batch
            notifications.add(notification);
        }

        List<Notification> savedNotifications = notificationRepository.saveAll(notifications);
        logger.info("Successfully saved {} notifications to the database", savedNotifications.size());

        for (Notification savedNotification : savedNotifications) {
            NotificationDTO dto = NotificationDTO.fromEntity(savedNotification);
            Long userId = savedNotification.getUser().getId();
            logger.info("Sending WebSocket notification to /topic/notifications/{}: {}", userId, dto);
            try {
                messagingTemplate.convertAndSend("/topic/notifications/" + userId, dto);
                logger.info("Successfully sent WebSocket notification to /topic/notifications/{}", userId);
            } catch (Exception e) {
                logger.error("Failed to send WebSocket notification to /topic/notifications/{}: {}", userId, e.getMessage(), e);
            }
        }
    }

    public List<Notification> getNotificationsByUserId(Long userId) {
        LocalDateTime now = LocalDateTime.now();
        logger.info("Current time for filtering notifications: {}", now); // Debug log
        return notificationRepository.findByUserId(userId).stream()
                .filter(notification -> notification.getExpiresAt().isAfter(now))
                .collect(Collectors.toList());
    }

    public List<Notification> getUnreadNotifications(Long userId) {
        LocalDateTime now = LocalDateTime.now();
        logger.info("Current time for filtering unread notifications: {}", now); // Debug log
        return notificationRepository.findByUserIdAndIsRead(userId, false).stream()
                .filter(notification -> notification.getExpiresAt().isAfter(now))
                .collect(Collectors.toList());
    }

    @Transactional
    public void markAsRead(Long notificationId, Long userId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalStateException("Notification not found with id: " + notificationId));
        if (!notification.getUser().getId().equals(userId)) {
            throw new IllegalStateException("You can only mark your own notifications as read");
        }
        if (notification.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new IllegalStateException("Cannot mark expired notification as read");
        }
        notification.setRead(true);
        notificationRepository.save(notification);
    }

    @Transactional
    public void deleteNotification(Long notificationId, Long userId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalStateException("Notification not found with id: " + notificationId));
        if (!notification.getUser().getId().equals(userId)) {
            throw new IllegalStateException("You can only delete your own notifications");
        }
        int deletedCount = notificationRepository.deleteByIdAndUserId(notificationId, userId);
        if (deletedCount == 0) {
            throw new IllegalStateException("Failed to delete notification: " + notificationId);
        }
        logger.info("Successfully deleted notification with id {} for user {}", notificationId, userId);
    }
}