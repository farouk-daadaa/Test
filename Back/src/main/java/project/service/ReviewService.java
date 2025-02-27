package project.service;

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
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ReviewService {

    @Autowired
    private ReviewRepository reviewRepository;

    @Autowired
    private EnrollmentRepository enrollmentRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private UserRepository userRepository;



    @Transactional
    public ReviewDTO createReview(Long courseId, Long userId, ReviewDTO reviewDTO) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        // Check if the user has completed the course
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

        // Update course rating
        updateCourseRating(course);

        return ReviewDTO.fromEntity(review);
    }

    @Transactional
    public ReviewDTO updateReview(Long reviewId, Long userId, ReviewDTO reviewDTO) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review not found"));

        // Compare the user IDs using long values
        if (review.getUser().getId() != userId) {
            throw new IllegalStateException("User is not authorized to update this review");
        }

        review.setRating(reviewDTO.getRating());
        review.setComment(reviewDTO.getComment());

        review = reviewRepository.save(review);

        // Update course rating
        updateCourseRating(review.getCourse());

        return ReviewDTO.fromEntity(review);
    }

    @Transactional
    public void deleteReview(Long reviewId, Long userId) {
        Review review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review not found"));

        // Compare the user IDs using long values
        if (review.getUser().getId() != userId) {
            throw new IllegalStateException("User is not authorized to delete this review");
        }

        reviewRepository.delete(review);

        // Update course rating
        updateCourseRating(review.getCourse());
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
            course.setRating(averageRating);
            course.setTotalReviews(reviews.size());
        } else {
            course.setRating(0.0);
            course.setTotalReviews(0);
        }
        courseRepository.save(course);
    }
}