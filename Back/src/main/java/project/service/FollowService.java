package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.Instructor;
import project.models.UserEntity;
import project.repository.InstructorRepository;
import project.repository.UserRepository;

import java.util.List;

@Service
public class FollowService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InstructorRepository instructorRepository;

    public void followInstructor(Long userId, Long instructorId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));
        if (!instructor.getFollowers().contains(user)) {
            instructor.getFollowers().add(user);
            user.getFollowedInstructors().add(instructor);
            instructorRepository.save(instructor);
        }
    }

    public void unfollowInstructor(Long userId, Long instructorId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));
        if (instructor.getFollowers().contains(user)) {
            instructor.getFollowers().remove(user);
            user.getFollowedInstructors().remove(instructor);
            instructorRepository.save(instructor);
        }
    }

    public List<UserEntity> getFollowers(Long instructorId) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));
        return instructor.getFollowers();
    }

    public List<Instructor> getFollowedInstructors(Long userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        return user.getFollowedInstructors();
    }

    public boolean isFollowing(Long userId, Long instructorId) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new IllegalStateException("Instructor not found: " + instructorId));
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("User not found: " + userId));
        return instructor.getFollowers().contains(user);
    }
}