package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Instructor;

@Getter
@Setter
public class InstructorProfileDTO {
    private String username;      // From UserEntity
    private String firstName;     // From UserEntity
    private String lastName;      // From UserEntity
    private int followersCount;   // Number of followers
    private int coursesCount;     // Number of courses taught
    private int totalReviews;     // Total reviews across all courses
    private boolean isFollowed;   // Whether the current user follows this instructor
    private byte[] imageBytes;    // Actual image data

    public static InstructorProfileDTO fromEntity(Instructor instructor, Long currentUserId) {
        InstructorProfileDTO dto = new InstructorProfileDTO();
        dto.setUsername(instructor.getUser().getUsername());
        dto.setFirstName(instructor.getUser().getFirstName());
        dto.setLastName(instructor.getUser().getLastName());
        dto.setFollowersCount(instructor.getFollowers().size());
        dto.setCoursesCount(instructor.getCourses().size());
        dto.setTotalReviews(instructor.getCourses().stream()
                .mapToInt(course -> course.getTotalReviews())
                .sum());
        dto.setIsFollowed(currentUserId != null && instructor.getFollowers().stream()
                .anyMatch(user -> user.getId().equals(currentUserId)));
        if (instructor.getUser().getUserImage() != null) {
            dto.setImageBytes(instructor.getUser().getUserImage().getPicByte());
        }
        return dto;
    }
    public void setIsFollowed(boolean isFollowed) {
        this.isFollowed = isFollowed;
    }
}