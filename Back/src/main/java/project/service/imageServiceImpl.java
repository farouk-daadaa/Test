package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import project.models.Image;
import project.models.UserEntity;
import project.repository.ImageRepository;
import project.repository.UserRepository;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Optional;
import java.util.zip.DataFormatException;
import java.util.zip.Deflater;
import java.util.zip.Inflater;

@Service
public class imageServiceImpl implements ImageServiceInter{


    @Autowired
    private UserRepository userRepository;
    @Autowired
    private ImageRepository imageRepository;
    @Override
    public ResponseEntity<String> uploadImage(MultipartFile file, int idUser) throws IOException {
        Optional<UserEntity> userOptional = userRepository.findById(idUser);

        if (userOptional.isPresent()) {
            if (userOptional.get().getUserImage()!= null) {

                return ResponseEntity.badRequest().body("User already has an image");
            }
            Image img = new Image();
            img.setName(file.getOriginalFilename());
            img.setPicByte(compressBytes(file.getBytes()));
            // img.setUserId(userOptional.get().getId());
            img.setUserEntity(userOptional.get());//badalneha
            imageRepository.save(img);
            return ResponseEntity.ok("image ( " + img.getName()+" ) added to user with ID:"+img.getUserEntity().getId()); // Use an appropriate endpoint or identifier

        }else {
            return ResponseEntity.notFound().build();//zedneha
        }    }




    @Override
    public ResponseEntity<Image> getImage(int idUser) {
        Optional<Image> retrivedImage = imageRepository.findByUserEntityId(idUser);
        if(retrivedImage.isPresent())
        {
            Image img =retrivedImage.get();
            img.setPicByte(decompressBytes(img.getPicByte()));
            return ResponseEntity.ok(img);
        }else {
            return ResponseEntity.notFound().build();
        }
    }

    @Override
    public ResponseEntity<String> updateImage(MultipartFile file, int idUser) throws IOException {

        Optional<UserEntity> userOptional=userRepository.findById(idUser);
        if(userOptional.isPresent())
        {
            UserEntity user= userOptional.get();
            Image image=user.getUserImage();
            image.setName(file.getOriginalFilename());
            image.setPicByte(compressBytes(file.getBytes()) );
            imageRepository.save(image);
            return ResponseEntity.ok("Updated");

        } else {
            return ResponseEntity.notFound().build();
        }
    }

    @Override
    public ResponseEntity<String> deleteImage(int idUser) {
        Optional<UserEntity> userOptional= userRepository.findById(idUser);
        if(userOptional.isPresent())
        {
            UserEntity user =userOptional.get();
            Image image =user.getUserImage();
            if(image!=null)
            {
                imageRepository.delete(image);
                return ResponseEntity.ok("Image deleted of user :"+idUser);
            }
            else {
                return ResponseEntity.notFound().build();
            }
        }else {
            return ResponseEntity.notFound().build();
        }    }





    // compress the image bytes before storing it in the database
    public static byte[] compressBytes(byte[] data) {
        Deflater deflater = new Deflater();
        deflater.setInput(data);
        deflater.finish();

        ByteArrayOutputStream outputStream = new ByteArrayOutputStream(data.length);
        byte[] buffer = new byte[1024];
        while (!deflater.finished()) {
            int count = deflater.deflate(buffer);
            outputStream.write(buffer, 0, count);
        }
        try {
            outputStream.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
        System.out.println("Compressed Image Byte Size - " + outputStream.toByteArray().length);

        return outputStream.toByteArray();
    }

    // uncompress the image bytes before returning it to the angular application
    public static byte[] decompressBytes(byte[] data) {
        Inflater inflater = new Inflater();
        inflater.setInput(data);
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream(data.length);
        byte[] buffer = new byte[1024];
        try {
            while (!inflater.finished()) {
                int count = inflater.inflate(buffer);
                outputStream.write(buffer, 0, count);
            }
            outputStream.close();
        } catch (IOException | DataFormatException e) {
            e.printStackTrace();
        }
        return outputStream.toByteArray();
    }



}
