package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Gender;
import project.models.UserEntity;
import project.models.UserRoleName;

import java.util.Date;


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
        dto.setCreationDate(user.getCreationDate());

        if (user.getUserImage() != null) {
            dto.setImage(ImageDTO.fromEntity(user.getUserImage()));
        }

        if (user.getInstructor() != null) {
            dto.setInstructor(InstructorDTO.fromEntity(user.getInstructor()));
        }

        return dto;
    }
}