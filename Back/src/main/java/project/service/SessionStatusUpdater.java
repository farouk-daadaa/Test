package project.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import project.models.Notification;
import project.models.Session;
import project.models.UserEntity;
import project.models.UserRoleName;
import project.repository.SessionRepository;
import project.repository.UserRepository;

import java.util.List;

@Component
public class SessionStatusUpdater {

    private static final Logger logger = LoggerFactory.getLogger(SessionStatusUpdater.class);

    @Autowired
    private SessionRepository sessionRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private NotificationService notificationService;

    @Scheduled(fixedRate = 60000)
    @Transactional
    public void updateSessionStatuses() {
        List<Session> sessions = sessionRepository.findAll();
        logger.info("Checking status for {} sessions", sessions.size());

        for (Session session : sessions) {
            Session.SessionStatus oldStatus = session.getStatus();
            session.updateStatus(); // Recalculate based on current time
            Session.SessionStatus newStatus = session.getStatus();

            if (!newStatus.equals(oldStatus)) {
                logger.info("Session {} status changed from {} to {}", session.getId(), oldStatus, newStatus);
                sessionRepository.save(session); // Persist the status change

                if (newStatus == Session.SessionStatus.LIVE) {
                    if (session.isFollowerOnly()) {
                        // Follower-only session: Notify only the instructor's followers
                        List<UserEntity> followers = session.getInstructor().getFollowers();
                        logger.info("Notifying {} followers for follower-only session {}", followers.size(), session.getId());
                        for (UserEntity follower : followers) {
                            notificationService.createNotification(
                                    follower.getId(),
                                    "Session Live: " + session.getTitle(),
                                    "The session by " + session.getInstructor().getUser().getUsername() +
                                            " is now live! Join here: " + session.getMeetingLink(),
                                    Notification.NotificationType.SESSION
                            );
                        }
                    } else {
                        // Public session: Notify all users with the USER role
                        logger.info("Notifying all users for public session {}", session.getId());
                        int page = 0;
                        int pageSize = 100;
                        List<UserEntity> users;
                        do {
                            // Use UserRoleName.USER instead of "USER"
                            users = userRepository.findByRole(UserRoleName.USER, PageRequest.of(page, pageSize));
                            logger.info("Fetched batch {} of users for public session {}: {} users", page, session.getId(), users.size());
                            for (UserEntity user : users) {
                                notificationService.createNotification(
                                        user.getId(),
                                        "Session Live: " + session.getTitle(),
                                        "The session by " + session.getInstructor().getUser().getUsername() +
                                                " is now live! Join here: " + session.getMeetingLink(),
                                        Notification.NotificationType.SESSION
                                );
                            }
                            page++;
                        } while (!users.isEmpty());
                    }
                }
            }
        }
    }
}