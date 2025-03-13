package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Instructor;

@Getter
@Setter
public class FollowedInstructorDTO {
    private Long id;          // Instructor ID
    private String username;  // Instructor's name from UserEntity
    private int followerCount;
    private boolean isFollowed;

    public static FollowedInstructorDTO fromEntity(Instructor instructor, Long currentUserId) {
        FollowedInstructorDTO dto = new FollowedInstructorDTO();
        dto.setId(instructor.getId());
        dto.setUsername(instructor.getUser().getUsername());
        dto.setFollowerCount(instructor.getFollowers().size());
        dto.setIsFollowed(currentUserId != null && instructor.getFollowers().stream()
                .anyMatch(user -> user.getId().equals(currentUserId)));
        return dto;
    }
    public void setIsFollowed(boolean isFollowed) {
        this.isFollowed = isFollowed;
    }
}