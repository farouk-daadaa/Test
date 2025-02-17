package project.models;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Setter
@Table(name = "enrollments")
public class Enrollment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    @JsonIgnoreProperties({"enrollments", "password", "roles", "instructor"})
    private UserEntity student;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id")
    @JsonIgnoreProperties({"enrollments", "instructor", "lessons", "reviews"})
    private Course course;

    @Enumerated(EnumType.STRING)
    private EnrollmentStatus status;

    private int progressPercentage;

    private LocalDateTime enrollmentDate;

    private LocalDateTime lastAccessedDate;


    @OneToMany(mappedBy = "enrollment", cascade = CascadeType.ALL)
    @JsonIgnoreProperties("enrollment")
    private List<LessonProgress> lessonProgresses = new ArrayList<>();
}