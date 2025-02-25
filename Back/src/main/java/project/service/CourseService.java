package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import project.dto.CourseDTO;
import project.models.*;
import project.repository.CourseCategoryRepository;
import project.repository.CourseRepository;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import project.exception.ResourceNotFoundException;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class CourseService {

    private final String UPLOAD_DIR = "uploads/courses/";

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private CourseCategoryRepository courseCategoryRepository;

    public CourseDTO createCourse(CourseDTO courseDTO, Long categoryId, String username, MultipartFile image) throws IOException {
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        Instructor instructor = instructorRepository.findByUser(user)
                .orElseThrow(() -> new ResourceNotFoundException("Instructor not found"));

        CourseCategory category = courseCategoryRepository.findById(categoryId)
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + categoryId));

        Course course = new Course();
        course.setTitle(courseDTO.getTitle());
        course.setDescription(courseDTO.getDescription());
        course.setPrice(courseDTO.getPrice());
        course.setPricingType(courseDTO.getPricingType());
        course.setLevel(courseDTO.getLevel());
        course.setLanguage(courseDTO.getLanguage());
        course.setInstructor(instructor);
        course.setCategory(category);
        course.setLastUpdate(LocalDate.now());
        course.setRating(0.0);
        course.setTotalReviews(0);
        course.setTotalStudents(0);

        if (image != null) {
            String imageUrl = uploadImage(image);
            course.setImageUrl(imageUrl);
        }

        handlePricingAndPrice(course);

        Course savedCourse = courseRepository.save(course);
        return CourseDTO.fromEntity(savedCourse);
    }

    public CourseDTO updateCourse(Long id, CourseDTO courseDTO, Long categoryId, MultipartFile image) throws IOException {
        Course course = getCourseEntityById(id);

        course.setTitle(courseDTO.getTitle());
        course.setDescription(courseDTO.getDescription());
        course.setLevel(courseDTO.getLevel());
        course.setLanguage(courseDTO.getLanguage());
        course.setLastUpdate(LocalDate.now());
        course.setPricingType(courseDTO.getPricingType());
        course.setPrice(courseDTO.getPrice());

        if (image != null) {
            // Delete old image if exists
            deleteImage(course.getImageUrl());
            // Upload and set new image
            String imageUrl = uploadImage(image);
            course.setImageUrl(imageUrl);
        }

        handlePricingAndPrice(course);

        if (categoryId != null) {
            CourseCategory category = courseCategoryRepository.findById(categoryId)
                    .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + categoryId));
            course.setCategory(category);
        }

        Course updatedCourse = courseRepository.save(course);
        return CourseDTO.fromEntity(updatedCourse);
    }

    private void handlePricingAndPrice(Course course) {
        if (course.getPricingType() == null) {
            course.setPricingType(PricingType.PAID);
        }

        if (course.getPricingType() == PricingType.FREE) {
            course.setPrice(BigDecimal.ZERO);
        } else if (course.getPrice() == null || course.getPrice().compareTo(BigDecimal.ZERO) < 0) {
            course.setPrice(BigDecimal.ZERO);
        }
    }

    public void deleteCourse(Long id) {
        Course course = getCourseEntityById(id);
        courseRepository.delete(course);
    }

    public CourseDTO getCourseById(Long id) {
        Course course = courseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + id));
        return CourseDTO.fromEntity(course);
    }

    public List<CourseDTO> getAllCourses() {
        return courseRepository.findAll().stream()
                .map(CourseDTO::fromEntity)
                .collect(Collectors.toList());
    }

    // This method is used internally and still returns the Course entity
    private Course getCourseEntityById(Long id) {
        return courseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + id));
    }
    private String uploadImage(MultipartFile image) throws IOException {
        if (image.isEmpty()) {
            throw new IllegalArgumentException("Image file is empty");
        }

        // Create the upload directory if it doesn't exist
        Path uploadPath = Paths.get(UPLOAD_DIR);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        // Generate a unique file name
        String originalFilename = image.getOriginalFilename();
        String extension = originalFilename != null ? originalFilename.substring(originalFilename.lastIndexOf(".")) : ".jpg";
        String fileName = UUID.randomUUID().toString() + extension;
        Path filePath = uploadPath.resolve(fileName);

        // Compress and save the image
        BufferedImage originalImage = ImageIO.read(image.getInputStream());

        // Create output stream to save compressed image
        OutputStream os = Files.newOutputStream(filePath);

        // Get image writers for the extension
        ImageWriter writer = ImageIO.getImageWritersByFormatName(extension.substring(1)).next();

        // Set compression
        ImageWriteParam param = writer.getDefaultWriteParam();
        if (param.canWriteCompressed()) {
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(0.7f);
        }

        // Write the compressed image
        writer.setOutput(ImageIO.createImageOutputStream(os));
        writer.write(null, new IIOImage(originalImage, null, null), param);

        // Clean up
        writer.dispose();
        os.close();

        return "/uploads/courses/" + fileName;
    }

    private void deleteImage(String imageUrl) {
        if (imageUrl != null && imageUrl.startsWith("/uploads/courses/")) {
            try {
                String fileName = imageUrl.substring("/uploads/courses/".length());
                Path filePath = Paths.get(UPLOAD_DIR + fileName);
                Files.deleteIfExists(filePath);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }
}
