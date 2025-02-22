package project.dto;

import lombok.Data;
import project.models.CourseCategory;

@Data
public class CourseCategoryDTO {
    private Long id;
    private String name;
    private int courseCount;

    public static CourseCategoryDTO fromEntity(CourseCategory category) {
        CourseCategoryDTO dto = new CourseCategoryDTO();
        dto.setId(category.getId());
        dto.setName(category.getName());
        dto.setCourseCount(category.getCourses() != null ? category.getCourses().size() : 0);
        return dto;
    }
}