package project.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import project.models.CourseCategory;
import project.models.Instructor;
import project.models.InstructorStatus;
import project.models.Notification;
import project.models.UserEntity;
import project.models.UserRoleName;
import project.repository.CourseCategoryRepository;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import project.exception.ResourceNotFoundException;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class CourseCategoryService {

    private static final Logger logger = LoggerFactory.getLogger(CourseCategoryService.class);

    @Autowired
    private CourseCategoryRepository courseCategoryRepository;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InstructorRepository instructorRepository; // Inject InstructorRepository

    private final String UPLOAD_DIR = "uploads/";

    public CourseCategory createCategory(CourseCategory category) {
        CourseCategory savedCategory = courseCategoryRepository.save(category);

        // Notify approved instructors about the new category
        notifyInstructorsOfNewCategory(savedCategory);

        return savedCategory;
    }

    private void notifyInstructorsOfNewCategory(CourseCategory category) {
        // Fetch all instructors with APPROVED status
        List<Instructor> approvedInstructors = instructorRepository.findByStatus(InstructorStatus.APPROVED);
        if (approvedInstructors.isEmpty()) {
            logger.info("No approved instructors found to notify for new category '{}'", category.getName());
            return; // No approved instructors to notify
        }

        // Map instructors to their corresponding UserEntity objects
        List<UserEntity> instructors = approvedInstructors.stream()
                .map(Instructor::getUser)
                .filter(user -> user != null && user.getUserRole() != null && user.getUserRole().getUserRoleName() == UserRoleName.INSTRUCTOR)
                .collect(Collectors.toList());

        if (instructors.isEmpty()) {
            logger.info("No approved instructors with valid user roles found to notify for new category '{}'", category.getName());
            return;
        }

        logger.info("Found {} approved instructors to notify for new category '{}'", instructors.size(), category.getName());

        // Prepare notification details
        String title = "New Course Category Added";
        String message = String.format("A new course category '%s' has been added. Check it out!", category.getName());

        // Send notifications to approved instructors
        List<Long> instructorIds = instructors.stream()
                .map(UserEntity::getId)
                .collect(Collectors.toList());
        notificationService.createNotificationsWithPagination(
                instructorIds,
                title,
                message,
                Notification.NotificationType.CATEGORY,
                UserRoleName.INSTRUCTOR
        );
    }

    public CourseCategory updateCategory(Long id, CourseCategory categoryDetails) {
        CourseCategory category = getCategoryById(id);
        category.setName(categoryDetails.getName());
        if (categoryDetails.getImageUrl() != null) {
            category.setImageUrl(categoryDetails.getImageUrl());
        }
        return courseCategoryRepository.save(category);
    }

    public void deleteCategory(Long id) {
        CourseCategory category = getCategoryById(id);
        // Delete the image file if it exists
        if (category.getImageUrl() != null) {
            try {
                String fileName = category.getImageUrl().substring("/uploads/".length());
                Path filePath = Paths.get(UPLOAD_DIR + fileName);
                Files.deleteIfExists(filePath);
            } catch (IOException e) {
                // Log the error but continue with category deletion
                e.printStackTrace();
            }
        }
        courseCategoryRepository.delete(category);
    }

    public CourseCategory getCategoryById(Long id) {
        return courseCategoryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + id));
    }

    public List<CourseCategory> getAllCategories() {
        return courseCategoryRepository.findAll();
    }

    public String uploadImage(MultipartFile image) throws IOException {
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
            param.setCompressionQuality(0.7f); // Set compression quality (0.0-1.0)
        }

        // Write the compressed image
        writer.setOutput(ImageIO.createImageOutputStream(os));
        writer.write(null, new IIOImage(originalImage, null, null), param);

        // Clean up
        writer.dispose();
        os.close();

        return "/uploads/" + fileName;
    }
}