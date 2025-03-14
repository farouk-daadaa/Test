package project.models;

import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Getter
@Setter
@Table(name = "sessions")
public class Session {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false, unique = true)
    private String meetingLink;

    @Column(nullable = false)
    private LocalDateTime startTime;

    @Column(nullable = false)
    private LocalDateTime endTime;

    @Column(nullable = false)
    private boolean isFollowerOnly;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "instructor_id", nullable = false)
    private Instructor instructor;

    // Auto-generate Jitsi Meet link only when saving to the database
    @PrePersist
    protected void generateMeetingLink() {
        if (this.meetingLink == null || this.meetingLink.isEmpty()) {
            this.meetingLink = "https://meet.jit.si/" + UUID.randomUUID().toString();
        }
    }

    public void setIsFollowerOnly(boolean isFollowerOnly) {
        this.isFollowerOnly = isFollowerOnly;
    }
}
