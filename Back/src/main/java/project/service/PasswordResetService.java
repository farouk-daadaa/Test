package project.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import project.models.PasswordResetToken;
import project.models.UserEntity;
import project.repository.PasswordResetTokenRepository;
import project.repository.UserRepository;

import java.util.Optional;
import java.util.Random;

@Service
public class PasswordResetService {
    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;

    public PasswordResetService(UserRepository userRepository,
                                PasswordResetTokenRepository tokenRepository,
                                EmailService emailService,
                                PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.emailService = emailService;
        this.passwordEncoder = passwordEncoder;
    }

    // Step 1: Generate code and send email
    public void sendResetCode(String email) {
        Optional<UserEntity> optionalUser = userRepository.findByEmail(email);
        if (optionalUser.isEmpty()) {
            throw new IllegalArgumentException("User not found with email: " + email);
        }

        UserEntity user = optionalUser.get();

        // Delete any existing token for this user
        tokenRepository.deleteByUser(user);

        // Generate a new 6-digit code
        String code = generateCode();
        PasswordResetToken passwordResetToken = new PasswordResetToken(code, user);
        tokenRepository.save(passwordResetToken);

        // Send reset email
        emailService.sendPasswordResetEmail(user.getEmail(), code);
    }

    // Step 2: Validate code
    public boolean isValidCode(String code) {
        PasswordResetToken resetToken = tokenRepository.findByToken(code);
        return resetToken != null && !resetToken.isExpired();
    }

    // Step 3: Reset password
    public void resetPassword(String code, String newPassword) {
        PasswordResetToken resetToken = tokenRepository.findByToken(code);
        if (resetToken == null || resetToken.isExpired()) {
            throw new IllegalArgumentException("Invalid or expired code.");
        }

        // Update user password
        UserEntity user = resetToken.getUser();
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        // Delete used token
        tokenRepository.delete(resetToken);
    }

    private String generateCode() {
        Random rnd = new Random();
        int number = rnd.nextInt(999999);
        return String.format("%06d", number);
    }
}

