package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.exception.ResourceNotFoundException;
import project.models.Instructor;
import project.models.UserEntity;
import project.repository.InstructorRepository;
import project.repository.UserRepository;

import javax.transaction.Transactional;
import java.util.List;

@Service
public class FollowService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private InstructorRepository instructorRepository;

    @Transactional
    public void followInstructor(Long userId, Long instructorId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new ResourceNotFoundException("Instructor not found with id: " + instructorId));

        // Prevent self-following
        if (instructor.getUser().getId().equals(userId)) {
            throw new IllegalStateException("You cannot follow yourself");
        }

        // Check if already following
        if (user.getFollowedInstructors().contains(instructor)) {
            throw new IllegalStateException("You are already following this instructor");
        }

        // Add the follow relationship
        user.getFollowedInstructors().add(instructor);
        instructor.getFollowers().add(user);
        userRepository.save(user); // Saving the user updates the join table
    }

    @Transactional
    public void unfollowInstructor(Long userId, Long instructorId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new ResourceNotFoundException("Instructor not found with id: " + instructorId));

        // Check if not following
        if (!user.getFollowedInstructors().contains(instructor)) {
            throw new IllegalStateException("You are not following this instructor");
        }

        // Remove the follow relationship
        user.getFollowedInstructors().remove(instructor);
        instructor.getFollowers().remove(user);
        userRepository.save(user); // Saving the user updates the join table
    }

    public List<UserEntity> getFollowers(Long instructorId) {
        Instructor instructor = instructorRepository.findById(instructorId)
                .orElseThrow(() -> new ResourceNotFoundException("Instructor not found with id: " + instructorId));
        return instructor.getFollowers();
    }

    public List<Instructor> getFollowedInstructors(Long userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
        return user.getFollowedInstructors();
    }
}