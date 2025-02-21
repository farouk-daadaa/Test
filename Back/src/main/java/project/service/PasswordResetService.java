package project.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import project.models.PasswordResetToken;
import project.models.UserEntity;
import project.repository.PasswordResetTokenRepository;
import project.repository.UserRepository;

import javax.transaction.Transactional;
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

    @Transactional
    public void sendResetCode(String email) {
        Optional<UserEntity> optionalUser = userRepository.findByEmail(email);
        if (optionalUser.isEmpty()) {
            throw new IllegalArgumentException("User not found with email: " + email);
        }

        UserEntity user = optionalUser.get();

        // FIX: Ensure transaction when deleting existing reset tokens
        tokenRepository.deleteByUser(user);

        // Generate new reset code
        String code = generateCode();
        PasswordResetToken passwordResetToken = new PasswordResetToken(code, user);
        tokenRepository.save(passwordResetToken);

        // Send email
        emailService.sendPasswordResetEmail(user.getEmail(), code);
    }

    // Step 2: Validate code
    public boolean isValidCode(String code) {
        PasswordResetToken resetToken = tokenRepository.findByToken(code);
        return resetToken != null && !resetToken.isExpired();
    }

    @Transactional
    public void resetPassword(String code, String newPassword) {
        PasswordResetToken resetToken = tokenRepository.findByToken(code);

        if (resetToken == null || resetToken.isExpired()) {
            throw new IllegalArgumentException("Invalid or expired reset code.");
        }

        UserEntity user = resetToken.getUser();
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        //  FIX: Delete the token AFTER the password update
        tokenRepository.delete(resetToken);
    }

    private String generateCode() {
        Random rnd = new Random();
        int number = rnd.nextInt(999999);
        return String.format("%06d", number);
    }
}

