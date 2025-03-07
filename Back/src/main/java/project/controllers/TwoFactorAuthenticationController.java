package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import project.service.TwoFactorAuthenticationService;

@RestController
@RequestMapping("/api/auth")
public class TwoFactorAuthenticationController {

    @Autowired
    private TwoFactorAuthenticationService twoFactorService;

    @PostMapping("/enable-2fa")
    public ResponseEntity<?> enableTwoFactorAuthentication(@RequestHeader("Authorization") String token, @RequestParam String username) {
        try {
            twoFactorService.enableTwoFactorAuthentication(token, username);
            return ResponseEntity.ok("{\"success\": true, \"message\": \"Two-Factor Authentication enabled\"}");
        } catch (SecurityException e) {
            return ResponseEntity.status(401).body("{\"success\": false, \"message\": \"Unauthorized\"}");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("{\"success\": false, \"message\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/disable-2fa")
    public ResponseEntity<?> disableTwoFactorAuthentication(@RequestHeader("Authorization") String token, @RequestParam String username) {
        try {
            twoFactorService.disableTwoFactorAuthentication(token, username);
            return ResponseEntity.ok("{\"success\": true, \"message\": \"Two-Factor Authentication disabled\"}");
        } catch (SecurityException e) {
            return ResponseEntity.status(401).body("{\"success\": false, \"message\": \"Unauthorized\"}");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("{\"success\": false, \"message\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/send-2fa-code")
    public ResponseEntity<?> sendTwoFactorCode(@RequestHeader("Authorization") String token, @RequestParam String username) {
        try {
            twoFactorService.sendTwoFactorCode(token, username);
            return ResponseEntity.ok("{\"success\": true, \"message\": \"Two-Factor code sent\"}");
        } catch (SecurityException e) {
            return ResponseEntity.status(401).body("{\"success\": false, \"message\": \"Unauthorized\"}");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("{\"success\": false, \"message\": \"" + e.getMessage() + "\"}");
        }
    }

    @PostMapping("/verify-2fa-code")
    public ResponseEntity<?> verifyTwoFactorCode(
            @RequestHeader("Authorization") String token,
            @RequestParam String username,
            @RequestParam String code) {
        try {
            boolean isValid = twoFactorService.verifyTwoFactorCode(token, username, code);
            if (isValid) {
                return ResponseEntity.ok("{\"success\": true, \"message\": \"Verification successful\"}");
            } else {
                return ResponseEntity.badRequest().body("{\"success\": false, \"message\": \"Invalid or expired code\"}");
            }
        } catch (SecurityException e) {
            return ResponseEntity.status(401).body("{\"success\": false, \"message\": \"Unauthorized\"}");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("{\"success\": false, \"message\": \"" + e.getMessage() + "\"}");
        }
    }
}