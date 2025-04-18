package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import project.dto.SessionRequestDTO;
import project.dto.SessionResponseDTO;
import project.exception.AccessDeniedException;
import project.models.Instructor;
import project.models.Session;
import project.models.UserEntity;
import project.repository.InstructorRepository;
import project.repository.SessionRepository;
import project.repository.UserRepository;
import project.security.UserSecurity;

import java.time.LocalDateTime;
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

    @Autowired
    private NotificationService notificationService;

    public SessionResponseDTO createSession(SessionRequestDTO sessionRequestDTO, Authentication authentication, String meetingLink) {
        String username = authentication.getName();
        Instructor instructor = userRepository.findByUsername(username)
                .map(userEntity -> userEntity.getInstructor())
                .orElseThrow(() -> new IllegalStateException("Instructor not found for user: " + username));
        if (!userSecurity.isApprovedInstructor((org.springframework.security.core.userdetails.User) authentication.getPrincipal())) {
            throw new IllegalStateException("Only approved instructors can create sessions");
        }

        LocalDateTime newStartTime = sessionRequestDTO.getStartTime();
        LocalDateTime newEndTime = sessionRequestDTO.getEndTime();
        if (!newEndTime.isAfter(newStartTime)) {
            throw new IllegalStateException("End time must be after start time");
        }

        List<Session> existingSessions = sessionRepository.findByInstructor(instructor);
        for (Session existing : existingSessions) {
            if (newStartTime.isBefore(existing.getEndTime()) && newEndTime.isAfter(existing.getStartTime())) {
                throw new IllegalStateException("This session overlaps with an existing session from " +
                        existing.getStartTime() + " to " + existing.getEndTime() + " (ID: " + existing.getId() + ")");
            }
        }

        Session session = new Session();
        session.setTitle(sessionRequestDTO.getTitle());
        session.setDescription(sessionRequestDTO.getDescription());
        session.setStartTime(newStartTime);
        session.setEndTime(newEndTime);
        session.setIsFollowerOnly(sessionRequestDTO.getIsFollowerOnly());
        session.setInstructor(instructor);
        session.setMeetingLink(meetingLink);
        Session savedSession = sessionRepository.save(session);
        return SessionResponseDTO.fromEntity(savedSession);
    }

    public List<SessionResponseDTO> getAvailableSessions(Long studentId, String statusFilter) {
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new IllegalStateException("Student not found with id: " + studentId));
        List<Instructor> followedInstructors = student.getFollowedInstructors();

        List<Session> sessions = sessionRepository.findAll().stream()
                .filter(session -> !session.isFollowerOnly() || followedInstructors.contains(session.getInstructor()))
                .collect(Collectors.toList());

        if (statusFilter != null && !statusFilter.isEmpty()) {
            Session.SessionStatus filterStatus = Session.SessionStatus.valueOf(statusFilter.toUpperCase());
            return sessions.stream()
                    .filter(session -> session.getCurrentStatus() == filterStatus) // Use dynamic status for filtering
                    .map(SessionResponseDTO::fromEntity)
                    .collect(Collectors.toList());
        }
        return sessions.stream()
                .map(SessionResponseDTO::fromEntity) // Dynamic status is handled here
                .collect(Collectors.toList());
    }

    public boolean joinSession(Long sessionId, Long studentId) {
        Session session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalStateException("Session not found with id: " + sessionId));
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new IllegalStateException("Student not found with id: " + studentId));
        List<Instructor> followedInstructors = student.getFollowedInstructors();

        if (!session.isFollowerOnly() || followedInstructors.contains(session.getInstructor())) {
            return true;
        } else {
            throw new AccessDeniedException("You are not allowed to join this follower-only session");
        }
    }

    public SessionResponseDTO updateSession(Long sessionId, SessionRequestDTO sessionRequestDTO, Authentication authentication) {
        String username = authentication.getName();
        Instructor instructor = userRepository.findByUsername(username)
                .map(userEntity -> userEntity.getInstructor())
                .orElseThrow(() -> new IllegalStateException("Instructor not found for user: " + username));
        if (!userSecurity.isApprovedInstructor((org.springframework.security.core.userdetails.User) authentication.getPrincipal())) {
            throw new IllegalStateException("Only approved instructors can update sessions");
        }

        Session session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalStateException("Session not found with id: " + sessionId));
        if (!session.getInstructor().equals(instructor)) {
            throw new IllegalStateException("You can only update your own sessions");
        }

        LocalDateTime newStartTime = sessionRequestDTO.getStartTime();
        LocalDateTime newEndTime = sessionRequestDTO.getEndTime();
        if (!newEndTime.isAfter(newStartTime)) {
            throw new IllegalStateException("End time must be after start time");
        }

        List<Session> existingSessions = sessionRepository.findByInstructor(instructor);
        for (Session existing : existingSessions) {
            if (!existing.getId().equals(sessionId) &&
                    newStartTime.isBefore(existing.getEndTime()) && newEndTime.isAfter(existing.getStartTime())) {
                throw new IllegalStateException("This session overlaps with an existing session from " +
                        existing.getStartTime() + " to " + existing.getEndTime() + " (ID: " + existing.getId() + ")");
            }
        }

        session.setTitle(sessionRequestDTO.getTitle());
        session.setDescription(sessionRequestDTO.getDescription());
        session.setStartTime(newStartTime);
        session.setEndTime(newEndTime);
        session.setIsFollowerOnly(sessionRequestDTO.getIsFollowerOnly());
        Session updatedSession = sessionRepository.save(session);
        return SessionResponseDTO.fromEntity(updatedSession);
    }

    public void deleteSession(Long sessionId, Authentication authentication) {
        String username = authentication.getName();
        Instructor instructor = userRepository.findByUsername(username)
                .map(userEntity -> userEntity.getInstructor())
                .orElseThrow(() -> new IllegalStateException("Instructor not found for user: " + username));
        if (!userSecurity.isApprovedInstructor((org.springframework.security.core.userdetails.User) authentication.getPrincipal())) {
            throw new IllegalStateException("Only approved instructors can delete sessions");
        }

        Session session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new IllegalStateException("Session not found with id: " + sessionId));
        if (!session.getInstructor().equals(instructor)) {
            throw new IllegalStateException("You can only delete your own sessions");
        }

        sessionRepository.delete(session);
    }
}