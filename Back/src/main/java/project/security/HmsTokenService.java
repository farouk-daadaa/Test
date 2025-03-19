package project.security;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Component
public class HmsTokenService {

    @Value("${hms.app.access.key}")
    private String APP_ACCESS_KEY;

    @Value("${hms.app.secret}")
    private String APP_SECRET;

    // Validate that the required properties are injected
    @PostConstruct
    public void init() {
        if (APP_ACCESS_KEY == null || APP_ACCESS_KEY.trim().isEmpty()) {
            throw new IllegalStateException("hms.app.access.key is not configured in application.properties");
        }
        if (APP_SECRET == null || APP_SECRET.trim().isEmpty()) {
            throw new IllegalStateException("hms.app.secret is not configured in application.properties");
        }
    }

    public String generateHmsToken(String roomId, String userId, String role) {
        if (roomId == null || roomId.trim().isEmpty()) {
            throw new IllegalArgumentException("roomId cannot be null or empty");
        }
        if (userId == null || userId.trim().isEmpty()) {
            throw new IllegalArgumentException("userId cannot be null or empty");
        }
        if (role == null || role.trim().isEmpty()) {
            throw new IllegalArgumentException("role cannot be null or empty");
        }

        Map<String, Object> claims = new HashMap<>();
        claims.put("access_key", APP_ACCESS_KEY);
        claims.put("room_id", roomId);
        claims.put("user_id", userId);
        claims.put("role", role);
        claims.put("type", "app");
        claims.put("version", 2);
        claims.put("iat", new Date().getTime() / 1000); // Issued at (Unix timestamp in seconds)
        claims.put("exp", new Date().getTime() / 1000 + 86400); // Expires in 24 hours (Unix timestamp in seconds)

        return Jwts.builder()
                .setClaims(claims)
                .setId(UUID.randomUUID().toString())
                .signWith(SignatureAlgorithm.HS256, APP_SECRET.getBytes())
                .compact();
    }
}