package project.dto;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AttendanceDTO {
    private Long studentId;
    private String username;
    private boolean checkedIn;

    public AttendanceDTO(Long studentId, String username, boolean checkedIn) {
        this.studentId = studentId;
        this.username = username;
        this.checkedIn = checkedIn;
    }
}