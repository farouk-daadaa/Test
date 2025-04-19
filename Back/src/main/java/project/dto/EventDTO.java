package project.dto;

import lombok.Getter;
import lombok.Setter;
import project.models.Event;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import java.time.LocalDateTime;

@Getter
@Setter
public class EventDTO {
    private Long id;

    @NotBlank(message = "Title is required")
    private String title;

    private String description;

    @NotNull(message = "Start date and time are required")
    private LocalDateTime startDateTime;

    @NotNull(message = "End date and time are required")
    private LocalDateTime endDateTime;

    private boolean isOnline;

    private String location;
    private String meetingLink;
    private String imageUrl;
    private Integer maxParticipants;
    private int currentParticipants;
    private Integer capacityLeft;
    private String status; // Event status

    public static EventDTO fromEntity(Event event) {
        EventDTO dto = new EventDTO();
        dto.setId(event.getId());
        dto.setTitle(event.getTitle());
        dto.setDescription(event.getDescription());
        dto.setStartDateTime(event.getStartDateTime());
        dto.setEndDateTime(event.getEndDateTime());
        dto.setIsOnline(event.isOnline());
        dto.setLocation(event.getLocation());
        dto.setMeetingLink(event.getMeetingLink());
        dto.setImageUrl(event.getImageUrl());
        dto.setMaxParticipants(event.getMaxParticipants());
        dto.setCurrentParticipants(event.getRegistrations().size());
        dto.setCapacityLeft(event.getMaxParticipants() != null ? event.getMaxParticipants() - event.getRegistrations().size() : null);
        dto.setStatus(event.getStatus().name());
        return dto;
    }

    public void setIsOnline(boolean isOnline) {
        this.isOnline = isOnline;
    }
}
