package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Review;

import javax.validation.constraints.Max;
import javax.validation.constraints.Min;
import javax.validation.constraints.NotNull;
import java.time.LocalDateTime;

@Getter
@Setter
public class ReviewDTO {

    private Long id;

    @NotNull
    @Min(1)
    @Max(5)
    private Double rating;

    private String comment;

    private LocalDateTime createdAt;

    private Long courseId;

    private long userId;

    private String username;

    public static ReviewDTO fromEntity(Review review) {
        ReviewDTO dto = new ReviewDTO();
        dto.setId(review.getId());
        dto.setRating(review.getRating());
        dto.setComment(review.getComment());
        dto.setCreatedAt(review.getCreatedAt());
        dto.setCourseId(review.getCourse().getId());
        dto.setUserId(review.getUser().getId());
        dto.setUsername(review.getUser().getUsername());
        return dto;
    }
}