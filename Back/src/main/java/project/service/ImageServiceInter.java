package project.service;

import org.springframework.http.ResponseEntity;
import org.springframework.web.multipart.MultipartFile;
import project.models.Image;

import java.io.IOException;

public interface ImageServiceInter {


    ResponseEntity<String> uploadImage(MultipartFile file, long idUser) throws IOException;

    ResponseEntity<Image> getImage(Long idUser);

    ResponseEntity<String> updateImage(MultipartFile file, long idUser) throws IOException;

    ResponseEntity<String> deleteImage(long idUser);
}
