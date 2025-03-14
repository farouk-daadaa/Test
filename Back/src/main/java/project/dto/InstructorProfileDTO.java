package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Instructor;
import project.models.Course; // Add this import
import com.fasterxml.jackson.annotation.JsonProperty;

@Getter
@Setter
public class InstructorProfileDTO {
    @JsonProperty("username")
    private String username;

    @JsonProperty("firstName")
    private String firstName;

    @JsonProperty("lastName")
    private String lastName;

    @JsonProperty("followersCount")
    private int followersCount;

    @JsonProperty("coursesCount")
    private int coursesCount;

    @JsonProperty("totalReviews")
    private int totalReviews;

    @JsonProperty("isFollowed")
    private boolean isFollowed;

    @JsonProperty("averageRating")
    private Double averageRating; // New field

    @JsonProperty("totalStudents")
    private int totalStudents; // New field

    @JsonProperty("imageBytes")
    private byte[] imageBytes;

    public static InstructorProfileDTO fromEntity(Instructor instructor, Long currentUserId) {
        InstructorProfileDTO dto = new InstructorProfileDTO();
        dto.setUsername(instructor.getUser().getUsername());
        dto.setFirstName(instructor.getUser().getFirstName());
        dto.setLastName(instructor.getUser().getLastName());
        dto.setFollowersCount(instructor.getFollowers().size());
        dto.setCoursesCount(instructor.getCourses().size());
        dto.setTotalReviews(instructor.getCourses().stream()
                .mapToInt(Course::getTotalReviews)
                .sum());
        dto.setAverageRating(instructor.getCourses().stream()
                .mapToDouble(Course::getRating) // Ensure Course has getRating()
                .average()
                .orElse(0.0));
        dto.setTotalStudents(instructor.getCourses().stream()
                .mapToInt(Course::getTotalStudents) // Ensure Course has getTotalStudents()
                .sum());
        boolean isFollowed = currentUserId != null && instructor.getFollowers().stream()
                .anyMatch(user -> user.getId().equals(currentUserId));
        dto.setIsFollowed(isFollowed);
        if (instructor.getUser().getUserImage() != null) {
            dto.setImageBytes(instructor.getUser().getUserImage().getPicByte());
        } else {
            dto.setImageBytes(null);
        }
        return dto;
    }

    public void setIsFollowed(boolean isFollowed) {
        this.isFollowed = isFollowed;
    }
}