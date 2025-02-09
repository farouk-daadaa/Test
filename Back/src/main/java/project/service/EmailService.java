package project.service;

import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {
    private final JavaMailSender mailSender;
    private final String fromEmail = "farouk.daadaa@esprit.tn";

    public EmailService(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    public void sendPasswordResetEmail(String to, String code) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(fromEmail);
        message.setTo(to);
        message.setSubject("Password Reset Request");
        message.setText("Your password reset code is: " + code + "\n\n" +
                "Enter this code in the app to reset your password.");

        mailSender.send(message);
    }

    public void sendInstructorSignUpEmail(String to) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(fromEmail);
        message.setTo(to);
        message.setSubject("Instructor Sign Up Confirmation");
        message.setText("Thank you for signing up as an instructor. Your application is currently under review. " +
                "We will notify you once your status has been updated.");

        mailSender.send(message);
    }

    public void sendInstructorStatusUpdateEmail(String to, String status) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(fromEmail);
        message.setTo(to);
        message.setSubject("Instructor Status Update");
        message.setText("Your instructor status has been updated to: " + status + "\n\n" +
                "If you have any questions, please contact our support team.");

        mailSender.send(message);
    }
}

