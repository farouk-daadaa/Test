package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.Instructor;
import project.models.Notification;
import project.models.UserEntity;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import javax.transaction.Transactional;

import java.util.List;

@Service
public class FollowService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private NotificationService notificationService; // Inject NotificationService

    @Transactional(rollbackOn = Exception.class)
    public void followInstructor(Long userId, Long instructorId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));

        if (!instructor.getFollowers().contains(user)) {
            // Add the user to the instructor's followers
            instructor.getFollowers().add(user);
            user.getFollowedInstructors().add(instructor);

            // Save the follow relationship first
            instructorRepository.save(instructor);

            // Ensure the instructor has an associated user
            UserEntity instructorUser = instructor.getUser();
            if (instructorUser == null) {
                throw new IllegalStateException("Instructor with ID " + instructorId + " is not associated with a user");
            }

            // Prevent self-follow notifications
            if (!instructorUser.getId().equals(userId)) {
                // Create a notification for the instructor
                String title = "New Follower";
                String message = String.format("You have a new follower: %s", user.getUsername());
                notificationService.createNotification(
                        instructorUser.getId(),
                        title,
                        message,
                        Notification.NotificationType.FOLLOWERS
                );
            }
        }
    }

    public void unfollowInstructor(Long userId, Long instructorId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));
        if (instructor.getFollowers().contains(user)) {
            instructor.getFollowers().remove(user);
            user.getFollowedInstructors().remove(instructor);
            instructorRepository.save(instructor);
        }
    }

    public List<UserEntity> getFollowers(Long instructorId) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));
        return instructor.getFollowers();
    }

    public List<Instructor> getFollowedInstructors(Long userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        return user.getFollowedInstructors();
    }

    public boolean isFollowing(Long userId, Long instructorId) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        return instructor.getFollowers().contains(user);
    }
}