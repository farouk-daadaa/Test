package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import project.dto.SessionRequestDTO;
import project.dto.SessionResponseDTO;
import project.models.Instructor;
import project.models.Session;
import project.models.UserEntity;
import project.repository.InstructorRepository;
import project.repository.SessionRepository;
import project.repository.UserRepository;
import project.security.UserSecurity;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class SessionService {

    @Autowired
    private SessionRepository sessionRepository;

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserSecurity userSecurity;

    public SessionResponseDTO createSession(SessionRequestDTO sessionRequestDTO, Authentication authentication) {
        // Get the authenticated instructor
        String username = authentication.getName();
        Instructor instructor = userRepository.findByUsername(username)
                .map(userEntity -> userEntity.getInstructor())
                .orElseThrow(() -> new IllegalStateException("Instructor not found for user: " + username));

        // Verify instructor is approved
        if (!userSecurity.isApprovedInstructor((org.springframework.security.core.userdetails.User) authentication.getPrincipal())) {
            throw new IllegalStateException("Only approved instructors can create sessions");
        }

        // Create and populate the session entity
        Session session = new Session();
        session.setTitle(sessionRequestDTO.getTitle());
        session.setDescription(sessionRequestDTO.getDescription());
        session.setStartTime(sessionRequestDTO.getStartTime());
        session.setEndTime(sessionRequestDTO.getEndTime());
        session.setIsFollowerOnly(sessionRequestDTO.getIsFollowerOnly());
        session.setInstructor(instructor);

        // Save the session (meetingLink will be auto-generated via @PrePersist)
        Session savedSession = sessionRepository.save(session);

        // Return the response DTO
        return SessionResponseDTO.fromEntity(savedSession);
    }

    public List<SessionResponseDTO> getAvailableSessions(Long studentId) {
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new IllegalStateException("Student not found with id: " + studentId));
        List<Instructor> followedInstructors = student.getFollowedInstructors();

        return sessionRepository.findAll().stream()
                .filter(session -> !session.isFollowerOnly() || followedInstructors.contains(session.getInstructor()))
                .map(SessionResponseDTO::fromEntity)
                .collect(Collectors.toList());
    }

    public String joinSession(Long sessionId, Long studentId) {
        Session session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalStateException("Session not found with id: " + sessionId));
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new IllegalStateException("Student not found with id: " + studentId));
        List<Instructor> followedInstructors = student.getFollowedInstructors();

        if (!session.isFollowerOnly() || followedInstructors.contains(session.getInstructor())) {
            return session.getMeetingLink();
        } else {
            throw new IllegalStateException("You are not allowed to join this follower-only session");
        }
    }
}