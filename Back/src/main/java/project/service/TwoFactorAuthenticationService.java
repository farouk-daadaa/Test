package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.UserEntity;
import project.repository.UserRepository;
import project.security.JWTGenerator;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

import java.util.Date;
import java.util.Random;

@Service
public class TwoFactorAuthenticationService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EmailService emailService;

    @Autowired
    private JavaMailSender mailSender;

    @Autowired
    private JWTGenerator jwtGenerator;

    private static final long CODE_EXPIRY_MINUTES = 5; // 5-minute expiry
    private static final int CODE_LENGTH = 6;

    public void enableTwoFactorAuthentication(String token, String username) {
        // Validate token
        if (!jwtGenerator.validateToken(token.replace("Bearer ", ""))) {
            throw new SecurityException("Invalid or expired token");
        }
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setTwoFactorEnabled(true);
        userRepository.save(user);
    }

    public void disableTwoFactorAuthentication(String token, String username) {
        // Validate token
        if (!jwtGenerator.validateToken(token.replace("Bearer ", ""))) {
            throw new SecurityException("Invalid or expired token");
        }
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setTwoFactorEnabled(false);
        user.setTwoFactorCode(null);
        user.setTwoFactorCodeExpiry(null);
        userRepository.save(user);
    }

    public void sendTwoFactorCode(String token, String username) {
        // Validate token
        if (!jwtGenerator.validateToken(token.replace("Bearer ", ""))) {
            throw new SecurityException("Invalid or expired token");
        }
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Generate a random 6-digit code
        String code = generateRandomCode();
        user.setTwoFactorCode(code);
        user.setTwoFactorCodeExpiry(new Date(System.currentTimeMillis() + CODE_EXPIRY_MINUTES * 60 * 1000));
        userRepository.save(user);

        // Send the code via email with a custom 2FA message
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom("farouk.daadaa@esprit.tn");
        message.setTo(user.getEmail()); // Use email instead of username for delivery
        message.setSubject("Your Two-Factor Authentication Code");
        message.setText("Your 2FA code is: " + code + "\n\n" +
                "This code expires in 5 minutes. Please enter it in the app to complete login.");
        mailSender.send(message);
    }

    public boolean verifyTwoFactorCode(String token, String username, String code) {
        // Validate token
        if (!jwtGenerator.validateToken(token.replace("Bearer ", ""))) {
            throw new SecurityException("Invalid or expired token");
        }
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (user.getTwoFactorCode() == null || user.getTwoFactorCodeExpiry() == null) {
            return false;
        }

        if (new Date().after(user.getTwoFactorCodeExpiry())) {
            user.setTwoFactorCode(null);
            user.setTwoFactorCodeExpiry(null);
            userRepository.save(user);
            return false;
        }

        boolean isValid = user.getTwoFactorCode().equals(code);
        if (isValid) {
            user.setTwoFactorCode(null);
            user.setTwoFactorCodeExpiry(null);
            userRepository.save(user);
        }
        return isValid;
    }

    private String generateRandomCode() {
        Random random = new Random();
        StringBuilder code = new StringBuilder();
        for (int i = 0; i < CODE_LENGTH; i++) {
            code.append(random.nextInt(10));
        }
        return code.toString();
    }
}