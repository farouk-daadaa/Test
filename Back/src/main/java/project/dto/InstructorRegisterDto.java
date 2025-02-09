package project.dto;

import lombok.Data;

@Data
public class InstructorRegisterDto {
    private String firstName;
    private String lastName;
    private String username;
    private String email;
    private String password;
    private String phone;
    private String cv;
    private String linkedinLink;
}