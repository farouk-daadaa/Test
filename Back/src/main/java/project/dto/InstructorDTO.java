package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Instructor;
import project.models.InstructorStatus;

@Getter
@Setter
public class InstructorDTO {
    private Long id;
    private String phone;
    private String cv;
    private String linkedinLink;
    private InstructorStatus status;

    public static InstructorDTO fromEntity(Instructor instructor) {
        InstructorDTO dto = new InstructorDTO();
        dto.setId(instructor.getId());
        dto.setPhone(instructor.getPhone());
        dto.setCv(instructor.getCv());
        dto.setLinkedinLink(instructor.getLinkedinLink());
        dto.setStatus(instructor.getStatus());
        return dto;
    }
}