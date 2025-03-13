package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.UserEntity;

@Getter
@Setter
public class FollowerDTO {
    private Long id;
    private String username;

    public static FollowerDTO fromEntity(UserEntity user) {
        FollowerDTO dto = new FollowerDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        return dto;
    }
}