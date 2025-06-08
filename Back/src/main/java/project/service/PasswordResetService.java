package project.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import project.models.PasswordResetToken;
import project.models.UserEntity;
import project.repository.PasswordResetTokenRepository;
import project.repository.UserRepository;

import javax.transaction.Transactional;
import java.util.List;
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
        List<PasswordResetToken> existingTokens = tokenRepository.findByUser(user);
        System.out.println("Existing tokens for user " + email + ": " + existingTokens.size());
        tokenRepository.deleteByUser(user);
        System.out.println("Deleted existing tokens for user " + email);

        String code = generateCode();
        PasswordResetToken passwordResetToken = new PasswordResetToken(code, user);
        tokenRepository.save(passwordResetToken);
        System.out.println("Saved new token: " + code);

        emailService.sendPasswordResetEmail(user.getEmail(), code);
    }
    // Step 2: Validate code
    public boolean isValidCode(String code) {
        PasswordResetToken resetToken = tokenRepository.findByToken(code);
        boolean isValid = resetToken != null && !resetToken.isExpired();
        System.out.println("Validating code: " + code + ", Token found: " + (resetToken != null) + ", Is valid: " + isValid);
        return isValid;
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

