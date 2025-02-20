package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.UserEntity;

@Getter
@Setter
public class AuthResponseDTO {
    private String accessToken;
    private String tokenType = "Bearer ";
    private UserDTO user;

    public AuthResponseDTO(String accessToken, UserEntity user) {
        this.accessToken = accessToken;
        this.user = UserDTO.fromEntity(user);
    }
}