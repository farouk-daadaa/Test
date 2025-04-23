package project.models;

import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Setter
@Table(name = "events")
public class Event {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false)
    private LocalDateTime startDateTime;

    @Column(nullable = false)
    private LocalDateTime endDateTime;

    @Column(nullable = false)
    private boolean isOnline;

    private String location; // For in-person events

    private String meetingLink; // For online events

    private String imageUrl; // Optional banner

    private Integer maxParticipants; // Optional limit

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EventStatus status = EventStatus.UPCOMING; // Event status

    @OneToMany(mappedBy = "event", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<EventRegistration> registrations = new ArrayList<>();

    public void setIsOnline(boolean isOnline) {
        this.isOnline = isOnline;
    }

    public enum EventStatus {
        UPCOMING, ONGOING, ENDED
    }

    @PrePersist
    @PreUpdate
    public void updateStatus() {
        LocalDateTime now = LocalDateTime.now();
        if (now.isBefore(startDateTime)) {
            status = EventStatus.UPCOMING;
        } else if (now.isAfter(endDateTime)) {
            status = EventStatus.ENDED;
        } else {
            status = EventStatus.ONGOING;
        }
    }
}