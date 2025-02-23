package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import project.models.Image;
import project.repository.UserRepository;
import project.service.ImageServiceInter;

import java.io.IOException;

@RestController
@RequestMapping("/image")
@CrossOrigin(origins = "*", allowedHeaders = "*")

public class ImageController {



    @Autowired
    UserRepository userRepository;


    @Autowired
    ImageServiceInter imageServiceInter;




    @PostMapping("/upload/{idUser}")
    public ResponseEntity<String> uploadImage(@RequestParam("imageFile") MultipartFile file, @PathVariable int idUser) throws IOException {
        return imageServiceInter.uploadImage(file,idUser);
    }

    @GetMapping("/get/{idUser}")
    public ResponseEntity<byte[]> getImageByidUser(@PathVariable Long idUser) {
        ResponseEntity<Image> imageResponse = imageServiceInter.getImage(idUser);
        if (imageResponse.getBody() != null) {
            return ResponseEntity.ok()
                    .contentType(MediaType.IMAGE_JPEG) // or MediaType.IMAGE_PNG depending on your image type
                    .body(imageResponse.getBody().getPicByte());
        }
        return ResponseEntity.notFound().build();
    }



    @PutMapping("/update/{idUser}")

    public ResponseEntity<String>updateImage(@RequestParam("imageFile") MultipartFile file,  @PathVariable int idUser) throws IOException {

        return imageServiceInter.updateImage(file,idUser);
    }



    @DeleteMapping("/delete/{idUser}")
    public ResponseEntity<String>deleteImage(@PathVariable int idUser)
    {
        return imageServiceInter.deleteImage(idUser);
    }


}
