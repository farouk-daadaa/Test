package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.ReviewDTO;
import project.models.UserEntity;
import project.repository.UserRepository;
import project.service.ReviewService;

import javax.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/reviews")
public class ReviewController {

    @Autowired
    private ReviewService reviewService;

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/courses/{courseId}")
    public ResponseEntity<ReviewDTO> createReview(@PathVariable Long courseId,
                                                  @Valid @RequestBody ReviewDTO reviewDTO,
                                                  Authentication authentication) {
        UserEntity user = getUserFromAuthentication(authentication);
        ReviewDTO createdReview = reviewService.createReview(courseId, user.getId(), reviewDTO);
        return new ResponseEntity<>(createdReview, HttpStatus.CREATED);
    }

    @PutMapping("/{reviewId}")
    public ResponseEntity<ReviewDTO> updateReview(@PathVariable Long reviewId,
                                                  @Valid @RequestBody ReviewDTO reviewDTO,
                                                  Authentication authentication) {
        UserEntity user = getUserFromAuthentication(authentication);
        ReviewDTO updatedReview = reviewService.updateReview(reviewId, user.getId(), reviewDTO);
        return ResponseEntity.ok(updatedReview);
    }

    @DeleteMapping("/{reviewId}")
    public ResponseEntity<Void> deleteReview(@PathVariable Long reviewId,
                                             Authentication authentication) {
        UserEntity user = getUserFromAuthentication(authentication);
        reviewService.deleteReview(reviewId, user.getId());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/courses/{courseId}")
    public ResponseEntity<List<ReviewDTO>> getReviewsByCourse(@PathVariable Long courseId,
                                                              @RequestParam(required = false, defaultValue = "latest") String sortBy) {
        List<ReviewDTO> reviews = reviewService.getReviewsByCourse(courseId, sortBy);
        return ResponseEntity.ok(reviews);
    }

    private UserEntity getUserFromAuthentication(Authentication authentication) {
        return userRepository.findByUsername(authentication.getName())
                .orElseThrow(() -> new RuntimeException("User not found"));
    }
}