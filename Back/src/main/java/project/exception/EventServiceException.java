package project.exception;

import org.springframework.http.HttpStatus;

// Custom exception for structured error handling
public class EventServiceException extends RuntimeException {
    private final HttpStatus status;

    public EventServiceException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}