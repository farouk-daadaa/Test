package project.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import project.models.Notification;
import project.repository.NotificationRepository;

import javax.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class NotificationCleanupService {

    private static final Logger logger = LoggerFactory.getLogger(NotificationCleanupService.class);

    @Autowired
    private NotificationRepository notificationRepository;

    // Run daily at midnight
    @Scheduled(cron = "0 0 0 * * ?")
    @Transactional
    public void deleteExpiredNotifications() {
        LocalDateTime now = LocalDateTime.now();
        logger.info("Running scheduled task to delete expired notifications at {}", now);

        int batchSize = 1000; // Delete in batches of 1000
        int totalDeleted = 0;
        Pageable pageable = PageRequest.of(0, batchSize);

        while (true) {
            // Fetch a batch of expired notifications
            List<Notification> expiredNotifications = notificationRepository.findByExpiresAtBefore(now, pageable);
            if (expiredNotifications.isEmpty()) {
                break; // No more notifications to delete
            }

            // Delete the batch
            List<Long> idsToDelete = expiredNotifications.stream()
                    .map(Notification::getId)
                    .collect(Collectors.toList());
            int deletedCount = notificationRepository.deleteByIds(idsToDelete);
            totalDeleted += deletedCount;

            logger.info("Deleted batch of {} expired notifications (total so far: {})", deletedCount, totalDeleted);

            // Move to the next page
            pageable = pageable.next();
        }

        logger.info("Completed cleanup: Deleted a total of {} expired notifications", totalDeleted);
    }
}