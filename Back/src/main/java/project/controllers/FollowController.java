package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.FollowedInstructorDTO;
import project.dto.FollowerDTO;
import project.models.Instructor;
import project.models.UserEntity;
import project.repository.UserRepository;
import project.service.FollowService;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/follow")
public class FollowController {

    @Autowired
    private FollowService followService;

    @Autowired
    private UserRepository userRepository;

    @PostMapping("/instructor/{instructorId}")
    public ResponseEntity<Void> followInstructor(@PathVariable Long instructorId, Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        try {
            boolean alreadyFollowing = followService.isFollowing(userId, instructorId);
            if (alreadyFollowing) {
                return ResponseEntity.status(HttpStatus.CONFLICT).build(); // 409 Conflict
            }
            followService.followInstructor(userId, instructorId);
            return new ResponseEntity<>(HttpStatus.CREATED); // 201 Created
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build(); // 500 on unexpected errors
        }
    }

    @DeleteMapping("/instructor/{instructorId}")
    public ResponseEntity<Void> unfollowInstructor(@PathVariable Long instructorId, Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        try {
            boolean isFollowing = followService.isFollowing(userId, instructorId);
            if (!isFollowing) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).build(); // 404 Not Found
            }
            followService.unfollowInstructor(userId, instructorId);
            return ResponseEntity.noContent().build(); // 204 No Content
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build(); // 500 on unexpected errors
        }
    }

    @GetMapping("/instructor/{instructorId}/followers")
    public ResponseEntity<List<FollowerDTO>> getFollowers(@PathVariable Long instructorId) {
        List<UserEntity> followers = followService.getFollowers(instructorId);
        List<FollowerDTO> followerDTOs = followers.stream()
                .map(FollowerDTO::fromEntity)
                .collect(Collectors.toList());
        return ResponseEntity.ok(followerDTOs);
    }

    @GetMapping("/my-followed-instructors")
    public ResponseEntity<List<FollowedInstructorDTO>> getFollowedInstructors(Authentication authentication) {
        Long userId = getUserIdFromAuthentication(authentication);
        List<Instructor> instructors = followService.getFollowedInstructors(userId);
        List<FollowedInstructorDTO> instructorDTOs = instructors.stream()
                .map(instructor -> FollowedInstructorDTO.fromEntity(instructor, userId))
                .collect(Collectors.toList());
        return ResponseEntity.ok(instructorDTOs);
    }

    private Long getUserIdFromAuthentication(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalStateException("User is not authenticated");
        }
        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));
        return user.getId();
    }
}