package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.EnrollmentStatus;

import java.time.LocalDateTime;

@Getter
@Setter
public class EnrollmentDTO {
    private Long id;
    private Long courseId;
    private String courseTitle;
    private String courseDescription;
    private EnrollmentStatus status;
    private int progressPercentage;
    private LocalDateTime enrollmentDate;
    private LocalDateTime lastAccessedDate;

    // Add any other relevant course information you want to include
}