package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Gender;
import project.models.UserEntity;
import project.models.UserRoleName;

import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;
import project.models.Instructor;

@Getter
@Setter
public class UserDTO {
    private Long id;
    private String username;
    private String email;
    private String firstName;
    private String lastName;
    private String phoneNumber;
    private Gender gender;
    private UserRoleName role;
    private Date creationDate;
    private InstructorDTO instructor;
    private ImageDTO image;
    private boolean twoFactorEnabled;
    private List<Long> followedInstructorIds;

    public static UserDTO fromEntity(UserEntity user, Long currentUserId) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setEmail(user.getEmail());
        dto.setFirstName(user.getFirstName());
        dto.setLastName(user.getLastName());
        dto.setPhoneNumber(user.getPhoneNumber());
        dto.setGender(user.getGender());
        dto.setRole(user.getUserRole().getUserRoleName());
        dto.setCreationDate(user.getCreationDate());
        dto.setTwoFactorEnabled(user.isTwoFactorEnabled());
        dto.setFollowedInstructorIds(user.getFollowedInstructors().stream()
                .map(Instructor::getId)
                .collect(Collectors.toList()));

        if (user.getUserImage() != null) {
            dto.setImage(ImageDTO.fromEntity(user.getUserImage()));
        }

        if (user.getInstructor() != null) {
            dto.setInstructor(InstructorDTO.fromEntity(user.getInstructor(), currentUserId));
        }

        return dto;
    }

    // Overloaded method for backward compatibility
    public static UserDTO fromEntity(UserEntity user) {
        return fromEntity(user, null); // Default to null if currentUserId isn’t provided
    }
}