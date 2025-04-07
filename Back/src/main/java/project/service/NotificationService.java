package project.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
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

    @Transactional
    public Notification createNotification(Long userId, String title, String message, Notification.NotificationType type) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found with id: " + userId));

        Notification notification = new Notification();
        notification.setUser(user);
        notification.setTitle(title);
        notification.setMessage(message);
        notification.setType(type);
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
    public void createNotificationsWithPagination(List<Long> userIds, String title, String message, Notification.NotificationType type) {
        logger.info("Creating notifications for {} users (with pagination)", userIds.size());

        if (!userIds.isEmpty()) {
            // If userIds are provided (e.g., followers), process them in batches
            int pageSize = 100; // Process 100 users at a time
            for (int i = 0; i < userIds.size(); i += pageSize) {
                List<Long> batchUserIds = userIds.subList(i, Math.min(i + pageSize, userIds.size()));
                List<UserEntity> users = userRepository.findAllById(batchUserIds).stream()
                        .filter(user -> user.getUserRole() != null && user.getUserRole().getUserRoleName() == UserRoleName.USER)
                        .collect(Collectors.toList());
                createNotificationBatch(users, title, message, type);
            }
        } else {
            // If userIds are not provided, fetch all students with pagination
            int pageSize = 100;
            Pageable pageable = PageRequest.of(0, pageSize);
            Page<UserEntity> userPage;

            do {
                userPage = userRepository.findByUserRole_UserRoleName(UserRoleName.USER, pageable);
                List<UserEntity> users = userPage.getContent();
                createNotificationBatch(users, title, message, type);
                pageable = pageable.next();
            } while (userPage.hasNext());
        }
    }

    private void createNotificationBatch(List<UserEntity> users, String title, String message, Notification.NotificationType type) {
        if (users.isEmpty()) {
            logger.warn("No users in batch to notify");
            return;
        }

        List<Notification> notifications = new ArrayList<>();
        for (UserEntity user : users) {
            Notification notification = new Notification();
            notification.setUser(user);
            notification.setTitle(title);
            notification.setMessage(message);
            notification.setType(type);
            notifications.add(notification);
        }

        // Batch save to database
        List<Notification> savedNotifications = notificationRepository.saveAll(notifications);
        logger.info("Successfully saved {} notifications to the database", savedNotifications.size());

        // Send WebSocket notifications
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
        return notificationRepository.findByUserId(userId);
    }

    public List<Notification> getUnreadNotifications(Long userId) {
        return notificationRepository.findByUserIdAndIsRead(userId, false);
    }

    @Transactional
    public void markAsRead(Long notificationId, Long userId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalStateException("Notification not found with id: " + notificationId));
        if (!notification.getUser().getId().equals(userId)) {
            throw new IllegalStateException("You can only mark your own notifications as read");
        }
        notification.setRead(true);
        notificationRepository.save(notification);
    }
}