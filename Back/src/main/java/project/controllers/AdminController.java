package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import project.dto.InstructorDTO;
import project.dto.UserDTO;
import project.models.Instructor;
import project.models.InstructorStatus;
import project.models.UserEntity;
import project.models.UserRoleName;
import project.repository.InstructorRepository;
import project.repository.UserRepository;
import project.service.EmailService;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private EmailService emailService;

    @Autowired
    private UserRepository userRepository;

    @PutMapping("/approve-instructor/{id}")
    public ResponseEntity<?> approveInstructor(@PathVariable Long id) {
        Instructor instructor = instructorRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Instructor not found"));

        instructor.setStatus(InstructorStatus.APPROVED);
        instructorRepository.save(instructor);

        // Send approval email
        emailService.sendInstructorStatusUpdateEmail(instructor.getUser().getEmail(), "APPROVED");

        return ResponseEntity.ok("Instructor approved successfully");
    }

    @PutMapping("/reject-instructor/{id}")
    public ResponseEntity<?> rejectInstructor(@PathVariable Long id) {
        Instructor instructor = instructorRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Instructor not found"));

        instructor.setStatus(InstructorStatus.REJECTED);
        instructorRepository.save(instructor);

        // Send rejection email
        emailService.sendInstructorStatusUpdateEmail(instructor.getUser().getEmail(), "REJECTED");

        return ResponseEntity.ok("Instructor rejected");
    }

    @GetMapping("/pending-instructors")
    public ResponseEntity<List<UserDTO>> getPendingInstructors() {
        List<UserDTO> instructors = instructorRepository.findByStatus(InstructorStatus.PENDING)
                .stream()
                .map(instructor -> {
                    UserDTO dto = UserDTO.fromEntity(instructor.getUser());
                    dto.setInstructor(InstructorDTO.fromEntity(instructor));
                    return dto;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(instructors);
    }

    @GetMapping("/instructors")
    public ResponseEntity<List<UserDTO>> getAllInstructors() {
        List<UserDTO> instructors = instructorRepository.findAll()
                .stream()
                .map(instructor -> {
                    UserDTO dto = UserDTO.fromEntity(instructor.getUser());
                    dto.setInstructor(InstructorDTO.fromEntity(instructor));
                    return dto;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(instructors);
    }

    @GetMapping("/students")
    public ResponseEntity<?> getAllStudents() {
        // Fetch users with the role "USER"
        List<UserEntity> students = userRepository.findByUserRole_UserRoleName(UserRoleName.USER);

        // Map to a simplified response
        List<Map<String, Object>> studentDetails = students.stream()
                .map(student -> {
                    Map<String, Object> details = new HashMap<>();
                    details.put("id", student.getId());
                    details.put("firstName", student.getFirstName());
                    details.put("lastName", student.getLastName());
                    details.put("username", student.getUsername());
                    details.put("email", student.getEmail());
                    details.put("gender", student.getGender());
                    details.put("phoneNumber", student.getPhoneNumber());
                    details.put("CreationDate",student.getCreationDate());
                    details.put("image",student.getUserImage());


                    return details;
                })
                .collect(Collectors.toList());

        return ResponseEntity.ok(studentDetails);
    }
}

