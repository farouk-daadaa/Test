package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.dto.CourseDTO;
import project.exception.ResourceNotFoundException;
import project.models.Bookmark;
import project.models.Course;
import project.models.UserEntity;
import project.repository.BookmarkRepository;
import project.repository.CourseRepository;
import project.repository.UserRepository;

import javax.transaction.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class BookmarkService {

    @Autowired
    private BookmarkRepository bookmarkRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Transactional
    public void addBookmark(Long userId, Long courseId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        if (bookmarkRepository.existsByUserAndCourse(user, course)) {
            throw new IllegalStateException("Course is already bookmarked");
        }

        Bookmark bookmark = new Bookmark();
        bookmark.setUser(user);
        bookmark.setCourse(course);
        bookmarkRepository.save(bookmark);
    }

    @Transactional
    public void removeBookmark(Long userId, Long courseId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new ResourceNotFoundException("Course not found"));

        Bookmark bookmark = bookmarkRepository.findByUserAndCourse(user, course)
                .orElseThrow(() -> new ResourceNotFoundException("Bookmark not found"));

        bookmarkRepository.delete(bookmark);
    }

    public List<CourseDTO> getBookmarkedCourses(Long userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        return bookmarkRepository.findByUser(user).stream()
                .map(bookmark -> CourseDTO.fromEntity(bookmark.getCourse()))
                .collect(Collectors.toList());
    }
}