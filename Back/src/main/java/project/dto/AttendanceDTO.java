package project.dto;

import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
public class AttendanceDTO {
    private Long studentId;
    private String username;
    private boolean checkedIn;
    private LocalDateTime checkInTime; // Add check-in time

    public AttendanceDTO(Long studentId, String username, boolean checkedIn) {
        this.studentId = studentId;
        this.username = username;
        this.checkedIn = checkedIn;
    }

    public AttendanceDTO(Long studentId, String username, boolean checkedIn, LocalDateTime checkInTime) {
        this.studentId = studentId;
        this.username = username;
        this.checkedIn = checkedIn;
        this.checkInTime = checkInTime;
    }
}