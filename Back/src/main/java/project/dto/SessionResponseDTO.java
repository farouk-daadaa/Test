package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Session;

import java.time.LocalDateTime;

@Getter
@Setter
public class SessionResponseDTO {
    private Long id;
    private String title;
    private String description;
    private String meetingLink;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private boolean isFollowerOnly;
    private Long instructorId;
    private Session.SessionStatus status;

    public static SessionResponseDTO fromEntity(Session session) {
        SessionResponseDTO dto = new SessionResponseDTO();
        dto.setId(session.getId());
        dto.setTitle(session.getTitle());
        dto.setDescription(session.getDescription());
        dto.setMeetingLink(session.getMeetingLink());
        dto.setStartTime(session.getStartTime());
        dto.setEndTime(session.getEndTime());
        dto.setIsFollowerOnly(session.isFollowerOnly());
        dto.setInstructorId(session.getInstructor().getId());
        dto.setStatus(session.getStatus());
        return dto;
    }
    public void setIsFollowerOnly(boolean isFollowerOnly) {
        this.isFollowerOnly = isFollowerOnly;
    }
}