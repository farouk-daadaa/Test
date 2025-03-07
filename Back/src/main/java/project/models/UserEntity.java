package project.models;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;

import javax.persistence.*;
import javax.validation.constraints.Pattern;
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
    private Long id;

    private String firstName;
    private String lastName;
    private String username;
    private String email;

    @JsonIgnore
    private String password;

    @Pattern(regexp = "^\\+?[1-9][0-9]{7,14}$", message = "Invalid phone number format")
    private String phoneNumber;

    @Enumerated(EnumType.STRING)
    private Gender gender;

    @Temporal(TemporalType.DATE)
    private Date creationDate;

    @OneToOne(mappedBy = "userEntity", cascade = CascadeType.ALL)
    @JsonIgnoreProperties("userEntity")
    @JsonIgnore
    private UserRole userRole;

    @JsonIgnore
    @OneToOne(mappedBy = "userEntity")
    private Image userImage;

    @OneToOne(mappedBy = "user", cascade = CascadeType.ALL)
    @JsonIgnoreProperties("user")
    private Instructor instructor;

    @OneToMany(mappedBy = "student")
    @JsonIgnoreProperties("student")
    private List<Enrollment> enrollments = new ArrayList<>();


    @Column(name = "two_factor_enabled")
    @JsonProperty("twoFactorEnabled")
    private boolean twoFactorEnabled = false; // New field for 2FA status

    @Column(name = "two_factor_code")
    @JsonIgnore
    private String twoFactorCode; // Temporary storage for 2FA code

    @Column(name = "two_factor_code_expiry")
    @JsonIgnore
    private Date twoFactorCodeExpiry; // Expiry time for the 2FA code


}