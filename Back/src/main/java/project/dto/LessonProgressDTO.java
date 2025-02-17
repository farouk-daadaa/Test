package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.LessonProgress;

import java.time.LocalDateTime;

@Getter
@Setter
public class LessonProgressDTO {
    private Long id;
    private Long enrollmentId;
    private Long lessonId;
    private LessonProgress.LessonStatus status;
    private LocalDateTime completedAt;

    public static LessonProgressDTO fromEntity(LessonProgress lessonProgress) {
        LessonProgressDTO dto = new LessonProgressDTO();
        dto.setId(lessonProgress.getId());
        dto.setEnrollmentId(lessonProgress.getEnrollment().getId());
        dto.setLessonId(lessonProgress.getLesson().getId());
        dto.setStatus(lessonProgress.getStatus());
        dto.setCompletedAt(lessonProgress.getCompletedAt());
        return dto;
    }
}