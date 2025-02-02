package project.controllers;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import project.dto.PasswordResetDTO;
import project.dto.PasswordResetRequestDTO;
import project.service.PasswordResetService;

@RestController
@RequestMapping("/api/auth")
public class PasswordResetController {
    private final PasswordResetService passwordResetService;

    public PasswordResetController(PasswordResetService passwordResetService) {
        this.passwordResetService = passwordResetService;
    }

    // Step 1: Request password reset
    @PostMapping("/forgot-password")
    public ResponseEntity<String> forgotPassword(@RequestBody PasswordResetRequestDTO request) {
        passwordResetService.sendResetCode(request.getEmail());
        return ResponseEntity.ok("Password reset code sent to your email.");
    }

    // Step 2: Validate code
    @GetMapping("/validate-reset-code")
    public ResponseEntity<Boolean> validateResetCode(@RequestParam("code") String code) {
        return ResponseEntity.ok(passwordResetService.isValidCode(code));
    }

    // Step 3: Reset password
    @PostMapping("/reset-password")
    public ResponseEntity<String> resetPassword(@RequestBody PasswordResetDTO request) {
        passwordResetService.resetPassword(request.getCode(), request.getNewPassword());
        return ResponseEntity.ok("Password successfully reset.");
    }
}

