package project.dto;

import lombok.Data;
import project.models.Image;

@Data
public class ImageDTO {
    private Long id;
    private String name;
    // Remove picByte from general responses

    public static ImageDTO fromEntity(Image image) {
        if (image == null) return null;

        ImageDTO dto = new ImageDTO();
        dto.setId(image.getId());
        dto.setName(image.getName());
        return dto;
    }
}
