package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Gender;
import project.models.UserEntity;
import project.models.UserRoleName;

@Getter
@Setter
public class UserDTO {
    private Long id;
    private String username;
    private String email;
    private String firstName;
    private String lastName;
    private String phoneNumber; // New field
    private Gender gender; // New field
    private UserRoleName role;
    private InstructorDTO instructor;

    public static UserDTO fromEntity(UserEntity user) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setEmail(user.getEmail());
        dto.setFirstName(user.getFirstName());
        dto.setLastName(user.getLastName());
        dto.setPhoneNumber(user.getPhoneNumber());
        dto.setGender(user.getGender());
        dto.setRole(user.getUserRole().getUserRoleName());

        if (user.getInstructor() != null) {
            dto.setInstructor(InstructorDTO.fromEntity(user.getInstructor()));
        }

        return dto;
    }
}