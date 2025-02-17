package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Course;
import project.models.CourseLanguage;
import project.models.CourseLevel;
import project.models.PricingType;

import javax.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class CourseDTO {
    private Long id;
    private String title;
    private String description;
    private BigDecimal price;
    private PricingType pricingType;
    private Double rating;
    private int totalReviews;
    private String imageUrl;
    @NotNull
    private CourseLevel level;
    @NotNull
    private CourseLanguage language;
    private int totalStudents;
    private LocalDate lastUpdate;
    private Long categoryId;
    private String instructorName;

    public static CourseDTO fromEntity(Course course) {
        CourseDTO dto = new CourseDTO();
        dto.setId(course.getId());
        dto.setTitle(course.getTitle());
        dto.setDescription(course.getDescription());
        dto.setPrice(course.getPrice());
        dto.setPricingType(course.getPricingType());
        dto.setRating(course.getRating());
        dto.setTotalReviews(course.getTotalReviews());
        dto.setImageUrl(course.getImageUrl());
        dto.setLevel(course.getLevel());
        dto.setLanguage(course.getLanguage());
        dto.setTotalStudents(course.getTotalStudents());
        dto.setLastUpdate(course.getLastUpdate());
        if (course.getCategory() != null) {
            dto.setCategoryId(course.getCategory().getId());
        }
        if (course.getInstructor() != null && course.getInstructor().getUser() != null) {
            dto.setInstructorName(course.getInstructor().getUser().getUsername());
        }
        return dto;
    }
}