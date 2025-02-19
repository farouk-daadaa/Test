package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.CourseDTO;
import project.models.UserEntity;
import project.repository.UserRepository;
import project.service.BookmarkService;

import java.util.List;

@RestController
@RequestMapping("/api/bookmarks")
public class BookmarkController {

    @Autowired
    private BookmarkService bookmarkService;

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/{courseId}")
    public ResponseEntity<Void> addBookmark(@PathVariable Long courseId, Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        bookmarkService.addBookmark(userId, courseId);
        return new ResponseEntity<>(HttpStatus.CREATED);
    }

    @DeleteMapping("/{courseId}")
    public ResponseEntity<Void> removeBookmark(@PathVariable Long courseId, Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        bookmarkService.removeBookmark(userId, courseId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    public ResponseEntity<List<CourseDTO>> getBookmarkedCourses(Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        List<CourseDTO> bookmarkedCourses = bookmarkService.getBookmarkedCourses(userId);
        return ResponseEntity.ok(bookmarkedCourses);
    }

    private Long getUserIdFromAuthentication(Authentication authentication) {
        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));
        return (long) user.getId();
    }
}