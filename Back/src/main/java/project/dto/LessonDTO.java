package project.dto;

import lombok.Data;
import project.models.Lesson;

@Data
public class LessonDTO {
    private Long id;
    private String title;
    private String videoUrl;

    public static LessonDTO fromEntity(Lesson lesson) {
        LessonDTO dto = new LessonDTO();
        dto.setId(lesson.getId());
        dto.setTitle(lesson.getTitle());
        dto.setVideoUrl(lesson.getVideoUrl());
        return dto;
    }
}