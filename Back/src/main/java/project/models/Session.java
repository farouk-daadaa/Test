package project.models;

import lombok.Getter;
import lombok.Setter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.persistence.*;
import java.time.LocalDateTime;

@Entity
@Getter
@Setter
@Table(name = "sessions")
public class Session {

    private static final Logger logger = LoggerFactory.getLogger(Session.class);

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = true)
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

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SessionStatus status;

    public enum SessionStatus {
        UPCOMING, LIVE, ENDED
    }

    @PrePersist
    protected void onCreate() {
        updateStatus(); // Set initial status on creation
    }

    @PreUpdate
    protected void onUpdate() {
        updateStatus(); // Update status on manual updates
    }

    // Made public for explicit calls (e.g., by the scheduled task)
    public void updateStatus() {
        LocalDateTime now = LocalDateTime.now();
        logger.info("Updating status: now={}, startTime={}, endTime={}", now, startTime, endTime);
        if (now.isBefore(startTime)) {
            this.status = SessionStatus.UPCOMING;
            logger.info("Status set to UPCOMING");
        } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
            this.status = SessionStatus.LIVE;
            logger.info("Status set to LIVE");
        } else {
            this.status = SessionStatus.ENDED;
            logger.info("Status set to ENDED");
        }
    }

    // Get the current status dynamically for API responses
    public SessionStatus getCurrentStatus() {
        updateStatus(); // Recalculates the status based on current time
        return this.status;
    }

    public void setIsFollowerOnly(boolean isFollowerOnly) {
        this.isFollowerOnly = isFollowerOnly;
    }

    public Long getInstructorId() {
        return instructor != null ? instructor.getId() : null;
    }
}