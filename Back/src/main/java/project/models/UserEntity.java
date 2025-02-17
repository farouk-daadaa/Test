package project.models;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonManagedReference;
import lombok.*;

import javax.persistence.*;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

@Entity
@Getter
@Setter
@Table(name = "users")
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class UserEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private long id;

    private String firstName;
    private String lastName;
    private String username;
    private String email;
    private String password;

    @Temporal(TemporalType.DATE)
    private Date creationDate;

    @OneToOne(mappedBy = "userEntity", cascade = CascadeType.ALL)
    private UserRole userRole;

    @JsonIgnore
    @OneToOne(mappedBy = "userEntity")
    private Image userImage;

    @JsonManagedReference
    @OneToOne(mappedBy = "user", cascade = CascadeType.ALL)
    private Instructor instructor;

    @OneToMany(mappedBy = "student")
    @JsonIgnoreProperties("student")
    private List<Enrollment> enrollments = new ArrayList<>();
}