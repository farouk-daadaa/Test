package project.models;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;
import javax.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Setter
@Table(name = "courses")
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Course {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Size(max = 255)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @NotNull
    @DecimalMin("0.0")
    @Column(precision = 10, scale = 2)
    private BigDecimal price;

    @Enumerated(EnumType.STRING)
    @NotNull
    private PricingType pricingType;

    @DecimalMin("0.0")
    @DecimalMax("5.0")
    private Double rating;

    @Min(0)
    private int totalReviews;

    private String imageUrl;

    @Enumerated(EnumType.STRING)
    @NotNull
    private CourseLevel level;

    @Enumerated(EnumType.STRING)
    @NotNull
    private CourseLanguage language;

    @Min(0)
    private int totalStudents;

    private LocalDate lastUpdate;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "instructor_id")
    @JsonIgnoreProperties({"courses", "user"})
    private Instructor instructor;

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL)
    @JsonIgnoreProperties("course")
    private List<Lesson> lessons = new ArrayList<>();

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL)
    @JsonIgnoreProperties("course")
    private List<Review> reviews = new ArrayList<>();

    @ManyToOne
    @JoinColumn(name = "category_id")
    @JsonIgnoreProperties("courses")
    private CourseCategory category;

    @OneToMany(mappedBy = "course")
    @JsonIgnoreProperties("course")
    private List<Enrollment> enrollments = new ArrayList<>();
}