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
    private int followerCount;
    @Setter
    private boolean isFollowed;

    public static InstructorDTO fromEntity(Instructor instructor, Long currentUserId) {
        InstructorDTO dto = new InstructorDTO();
        dto.setId(instructor.getId());
        dto.setPhone(instructor.getPhone());
        dto.setCv(instructor.getCv());
        dto.setLinkedinLink(instructor.getLinkedinLink());
        dto.setStatus(instructor.getStatus());
        dto.setFollowerCount(instructor.getFollowers().size());
        // Check if the current user follows this instructor
        dto.setIsFollowed(currentUserId != null && instructor.getFollowers().stream()
                .anyMatch(user -> user.getId().equals(currentUserId)));
        return dto;
    }
    public void setIsFollowed(boolean isFollowed) {
        this.isFollowed = isFollowed;
    }
    // Overloaded method for cases where currentUserId is not needed
    public static InstructorDTO fromEntity(Instructor instructor) {
        return fromEntity(instructor, null);  // Calls the main method with 'null'
    }


}