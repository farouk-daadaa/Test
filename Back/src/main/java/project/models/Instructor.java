package project.models;

import com.fasterxml.jackson.annotation.JsonBackReference;
import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Setter
@Table(name = "instructors")
public class Instructor {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @JsonBackReference
    @OneToOne
    @JoinColumn(name = "user_id", referencedColumnName = "id")
    private UserEntity user;

    private String phone;
    private String cv;
    private String linkedinLink;

    @Enumerated(EnumType.STRING)
    private InstructorStatus status = InstructorStatus.PENDING;

    @OneToMany(mappedBy = "instructor", cascade = CascadeType.ALL)
    private List<Course> courses = new ArrayList<>();
    // Getter for status
    public InstructorStatus getStatus() {
        return status;
    }

    // Setter for status
    public void setStatus(InstructorStatus status) {
        this.status = status;
    }
}