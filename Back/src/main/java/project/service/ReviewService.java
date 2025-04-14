package project.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.dto.ReviewDTO;
import project.exception.ResourceNotFoundException;
import project.models.*;
import project.repository.CourseRepository;
import project.repository.EnrollmentRepository;
import project.repository.ReviewRepository;
import project.repository.UserRepository;

import javax.transaction.Transactional;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@Service
public class ReviewService {

    private static final Logger logger = LoggerFactory.getLogger(ReviewService.class);

    @Autowired
    private ReviewRepository reviewRepository;

    @Autowired
    private EnrollmentRepository enrollmentRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private NotificationService notificationService;

    @Transactional
    public ReviewDTO createReview(Long courseId, Long userId, ReviewDTO reviewDTO) {
        logger.info("User {} is attempting to create a review for course {}", userId, courseId);

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Enrollment enrollment = enrollmentRepository.findByCourseAndStudent(course, user)
                .orElseThrow(() -> new IllegalStateException("User is not enrolled in this course"));

        if (enrollment.getStatus() != EnrollmentStatus.COMPLETED) {
            throw new IllegalStateException("User has not completed this course");
        }

        Review review = new Review();
        review.setRating(reviewDTO.getRating());
        review.setComment(reviewDTO.getComment());
        review.setCourse(course);
        review.setUser(user);

        review = reviewRepository.save(review);
        logger.info("Review {} created successfully for course {} by user {}", review.getId(), courseId, userId);

        updateCourseRating(course);

        Instructor instructor = course.getInstructor();
        if (instructor == null) {
            logger.error("Course with ID {} is not associated with an instructor", courseId);
            throw new IllegalStateException("Course with ID " + courseId + " is not associated with an instructor");
        }

        UserEntity instructorUser = instructor.getUser();
        if (instructorUser == null) {
            logger.error("Instructor with ID {} is not associated with a user", instructor.getId());
            throw new IllegalStateException("Instructor with ID " + instructor.getId() + " is not associated with a user");
        }

        if (!instructorUser.getId().equals(userId)) {
            String title = "New Review";
            String message = String.format(
                    Locale.US,
                    "A new review has been added to your course '%s' by %s. Rating: %.1f [Course ID: %d]",
                    course.getTitle(),
                    user.getUsername(),
                    review.getRating(),
                    course.getId()
            );
            logger.info("Creating notification for instructor user {}: {}", instructorUser.getId(), message);
            notificationService.createNotification(
                    instructorUser.getId(),
                    title,
                    message,
                    Notification.NotificationType.REVIEW
            );
        } else {
            logger.info("Skipping notification: User {} reviewed their own course {}", userId, courseId);
        }

        return ReviewDTO.fromEntity(review);
    }

    @Transactional
    public ReviewDTO updateReview(Long reviewId, Long userId, ReviewDTO reviewDTO) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review not found"));

        if (review.getUser().getId() != userId) {
            throw new IllegalStateException("User is not authorized to update this review");
        }

        review.setRating(reviewDTO.getRating());
        review.setComment(reviewDTO.getComment());

        review = reviewRepository.save(review);

        Course course = review.getCourse();
        updateCourseRating(course);

        Instructor instructor = course.getInstructor();
        if (instructor == null) {
            logger.error("Course with ID {} is not associated with an instructor", course.getId());
            throw new IllegalStateException("Course with ID " + course.getId() + " is not associated with an instructor");
        }

        UserEntity instructorUser = instructor.getUser();
        if (instructorUser == null) {
            logger.error("Instructor with ID {} is not associated with a user", instructor.getId());
            throw new IllegalStateException("Instructor with ID " + instructor.getId() + " is not associated with a user");
        }

        if (!instructorUser.getId().equals(userId)) {
            String title = "Review Updated";
            String message = String.format(
                    Locale.US,
                    "A review for your course '%s' by %s has been updated. New Rating: %.1f [Course ID: %d]",
                    course.getTitle(),
                    review.getUser().getUsername(),
                    review.getRating(),
                    course.getId()
            );
            logger.info("Creating notification for instructor user {}: {}", instructorUser.getId(), message);
            notificationService.createNotification(
                    instructorUser.getId(),
                    title,
                    message,
                    Notification.NotificationType.REVIEW
            );
        } else {
            logger.info("Skipping notification: User {} updated their own review for course {}", userId, course.getId());
        }

        return ReviewDTO.fromEntity(review);
    }

    @Transactional
    public void deleteReview(Long reviewId, Long userId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review not found"));

        if (review.getUser().getId() != userId) {
            throw new IllegalStateException("User is not authorized to delete this review");
        }

        Course course = review.getCourse();
        UserEntity user = review.getUser();

        reviewRepository.delete(review);
        updateCourseRating(course);

        Instructor instructor = course.getInstructor();
        if (instructor == null) {
            logger.error("Course with ID {} is not associated with an instructor", course.getId());
            throw new IllegalStateException("Course with ID " + course.getId() + " is not associated with an instructor");
        }

        UserEntity instructorUser = instructor.getUser();
        if (instructorUser == null) {
            logger.error("Instructor with ID {} is not associated with a user", instructor.getId());
            throw new IllegalStateException("Instructor with ID " + instructor.getId() + " is not associated with a user");
        }

        if (!instructorUser.getId().equals(userId)) {
            String title = "Review Deleted";
            String message = String.format(
                    Locale.US,
                    "A review for your course '%s' by %s has been deleted. [Course ID: %d]",
                    course.getTitle(),
                    user.getUsername(),
                    course.getId()
            );
            logger.info("Creating notification for instructor user {}: {}", instructorUser.getId(), message);
            notificationService.createNotification(
                    instructorUser.getId(),
                    title,
                    message,
                    Notification.NotificationType.REVIEW
            );
        } else {
            logger.info("Skipping notification: User {} deleted their own review for course {}", userId, course.getId());
        }
    }

    public List<ReviewDTO> getReviewsByCourse(Long courseId, String sortBy) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        List<Review> reviews;
        if ("latest".equalsIgnoreCase(sortBy)) {
            reviews = reviewRepository.findByCourseOrderByCreatedAtDesc(course);
        } else if ("rating".equalsIgnoreCase(sortBy)) {
            reviews = reviewRepository.findByCourseOrderByRatingDesc(course);
        } else {
            reviews = reviewRepository.findByCourse(course);
        }

        return reviews.stream()
                .map(ReviewDTO::fromEntity)
                .collect(Collectors.toList());
    }

    private void updateCourseRating(Course course) {
        List<Review> reviews = reviewRepository.findByCourse(course);
        if (!reviews.isEmpty()) {
            double averageRating = reviews.stream()
                    .mapToDouble(Review::getRating)
                    .average()
                    .orElse(0.0);
            // Round to 1 decimal place
            BigDecimal roundedRating = BigDecimal.valueOf(averageRating)
                    .setScale(1, RoundingMode.HALF_UP);
            course.setRating(roundedRating.doubleValue());
            course.setTotalReviews(reviews.size());
        } else {
            course.setRating(0.0);
            course.setTotalReviews(0);
        }
        courseRepository.save(course);
    }
}