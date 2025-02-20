package project.utils;

import org.springframework.core.io.ClassPathResource;
import org.springframework.util.StreamUtils;

import java.io.IOException;

public class DefaultImageUtil {

    public static byte[] getDefaultImage() {
        try {
            // Store default image in resources/images/default-profile.jpg
            ClassPathResource imageResource = new ClassPathResource("images/default-profile.jpg");
            return StreamUtils.copyToByteArray(imageResource.getInputStream());
        } catch (IOException e) {
            throw new RuntimeException("Could not load default image", e);
        }
    }
}