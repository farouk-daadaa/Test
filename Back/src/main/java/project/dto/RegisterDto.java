package project.dto;

import lombok.Data;
import project.models.Gender;

@Data
public class RegisterDto {
    private String firstName;
    private String lastName;
    private String username;
    private String email;
    private String password;
    private String phoneNumber;
    private Gender gender;
}