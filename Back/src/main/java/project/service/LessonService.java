package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import project.dto.LessonDTO;
import project.models.Course;
import project.models.Lesson;
import project.repository.CourseRepository;
import project.repository.LessonRepository;
import project.exception.ResourceNotFoundException;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class LessonService {

    @Autowired
    private LessonRepository lessonRepository;

    @Autowired
    private CourseRepository courseRepository;

    private final String UPLOAD_DIR = "uploads/videos/";
    private final long MAX_VIDEO_SIZE = 500 * 1024 * 1024; // 500MB
    private final String[] ALLOWED_VIDEO_TYPES = {
            "video/mp4", "video/mpeg", "video/quicktime", "video/x-msvideo"
    };

    private String uploadVideo(MultipartFile video) throws IOException {
        if (video.isEmpty()) {
            throw new IllegalArgumentException("Video file is empty");
        }

        // Check file size
        if (video.getSize() > MAX_VIDEO_SIZE) {
            throw new IllegalArgumentException("Video file size exceeds maximum limit of 500MB");
        }

        // Check file type
        String contentType = video.getContentType();
        boolean isValidType = false;
        for (String allowedType : ALLOWED_VIDEO_TYPES) {
            if (allowedType.equals(contentType)) {
                isValidType = true;
                break;
            }
        }
        if (!isValidType) {
            throw new IllegalArgumentException("Invalid video format. Allowed formats: MP4, MPEG, MOV, AVI");
        }

        // Create upload directory if it doesn't exist
        Path uploadPath = Paths.get(UPLOAD_DIR);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        // Generate unique filename
        String originalFilename = video.getOriginalFilename();
        String extension = originalFilename != null ?
                originalFilename.substring(originalFilename.lastIndexOf(".")) : ".mp4";
        String fileName = UUID.randomUUID().toString() + extension;
        Path filePath = uploadPath.resolve(fileName);

        // Save the file
        Files.copy(video.getInputStream(), filePath);

        return "/uploads/videos/" + fileName;
    }

    private void deleteVideo(String videoUrl) {
        if (videoUrl != null && videoUrl.startsWith("/uploads/videos/")) {
            try {
                String fileName = videoUrl.substring("/uploads/videos/".length());
                Path filePath = Paths.get(UPLOAD_DIR + fileName);
                Files.deleteIfExists(filePath);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    public LessonDTO getLessonById(Long id) {
        Lesson lesson = lessonRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Lesson not found with id: " + id));
        return LessonDTO.fromEntity(lesson);
    }

    public List<LessonDTO> getAllLessonsByCourseId(Long courseId) {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + courseId));
        return course.getLessons().stream()
                .map(LessonDTO::fromEntity)
                .collect(Collectors.toList());
    }

    public LessonDTO addLesson(Long courseId, String title, MultipartFile video) throws IOException {
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found with id: " + courseId));

        Lesson lesson = new Lesson();
        lesson.setTitle(title);
        lesson.setCourse(course);

        if (video != null) {
            String videoUrl = uploadVideo(video);
            lesson.setVideoUrl(videoUrl);
        }

        Lesson savedLesson = lessonRepository.save(lesson);
        return LessonDTO.fromEntity(savedLesson);
    }

    public LessonDTO updateLesson(Long id, String title, MultipartFile video) throws IOException {
        Lesson lesson = lessonRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Lesson not found with id: " + id));

        lesson.setTitle(title);

        if (video != null) {
            // Delete old video if exists
            deleteVideo(lesson.getVideoUrl());
            // Upload and set new video
            String videoUrl = uploadVideo(video);
            lesson.setVideoUrl(videoUrl);
        }

        Lesson updatedLesson = lessonRepository.save(lesson);
        return LessonDTO.fromEntity(updatedLesson);
    }

    public void deleteLesson(Long id) {
        Lesson lesson = lessonRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Lesson not found with id: " + id));

        // Delete video file if exists
        deleteVideo(lesson.getVideoUrl());

        lessonRepository.delete(lesson);
    }
}