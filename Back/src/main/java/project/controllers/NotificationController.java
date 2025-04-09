package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.NotificationDTO;
import project.models.Notification;
import project.models.UserEntity;
import project.repository.UserRepository;
import project.service.NotificationCleanupService;
import project.service.NotificationService;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    @Autowired
    private NotificationCleanupService cleanupService;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<NotificationDTO>> getNotifications(
            Authentication authentication,
            @RequestParam(required = false, defaultValue = "false") boolean unreadOnly) {
        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));

        List<Notification> notifications;
        if (unreadOnly) {
            notifications = notificationService.getUnreadNotifications(user.getId());
        } else {
            notifications = notificationService.getNotificationsByUserId(user.getId());
        }

        List<NotificationDTO> notificationDTOs = notifications.stream()
                .map(NotificationDTO::fromEntity)
                .collect(Collectors.toList());
        return ResponseEntity.ok(notificationDTOs);
    }

    @PutMapping("/{notificationId}/read")
    public ResponseEntity<Void> markAsRead(
            @PathVariable Long notificationId,
            Authentication authentication) {
        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));

        notificationService.markAsRead(notificationId, user.getId());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{notificationId}")
    public ResponseEntity<Void> deleteNotification(
            @PathVariable Long notificationId,
            Authentication authentication) {
        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));

        notificationService.deleteNotification(notificationId, user.getId());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/cleanup-notifications")
    public ResponseEntity<String> triggerCleanup() {
        cleanupService.deleteExpiredNotifications();
        return ResponseEntity.ok("Cleanup triggered");
    }

}