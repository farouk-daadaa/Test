package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import project.models.Instructor;
import project.models.InstructorStatus;
import project.repository.InstructorRepository;
import project.service.EmailService;
import java.util.List;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    @Autowired
    private InstructorRepository instructorRepository;

    @Autowired
    private EmailService emailService;

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
    public ResponseEntity<?> getPendingInstructors() {
        return ResponseEntity.ok(instructorRepository.findByStatus(InstructorStatus.PENDING));
    }

    @GetMapping("/instructors")
    public ResponseEntity<?> getAllInstructors() {
        List<Instructor> instructors = instructorRepository.findAll();
        return ResponseEntity.ok(instructors);
    }
}

