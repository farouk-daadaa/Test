package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import project.dto.AttendanceDTO;
import project.dto.EventDTO;
import project.models.Event;
import project.models.UserEntity;
import project.repository.EventRepository;
import project.repository.UserRepository;
import project.security.HmsTokenService;
import project.service.EventService;
import project.exception.EventServiceException;

import javax.validation.Valid;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/events")
public class EventController {

    @Autowired
    private EventService eventService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private HmsTokenService hmsTokenService;

    @Autowired
    private EventRepository eventRepository;

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> createEvent(@Valid @RequestBody EventDTO eventDTO, Authentication authentication) {
        try {
            Long adminId = getUserIdFromAuthentication(authentication);
            EventDTO createdEvent = eventService.createEvent(eventDTO, adminId);
            return new ResponseEntity<>(createdEvent, HttpStatus.CREATED);
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    @PutMapping("/{eventId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> updateEvent(@PathVariable Long eventId, @Valid @RequestBody EventDTO eventDTO, Authentication authentication) {
        try {
            Long adminId = getUserIdFromAuthentication(authentication);
            EventDTO updatedEvent = eventService.updateEvent(eventDTO, eventId, adminId);
            return ResponseEntity.ok(updatedEvent);
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    @DeleteMapping("/{eventId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> deleteEvent(@PathVariable Long eventId, Authentication authentication) {
        try {
            Long adminId = getUserIdFromAuthentication(authentication);
            eventService.deleteEvent(eventId, adminId);
            return ResponseEntity.noContent().build();
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    @GetMapping
    public ResponseEntity<Page<EventDTO>> getAllEvents(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(required = false) String status) {
        Pageable pageable = PageRequest.of(page, size);
        Page<EventDTO> events = eventService.getAllEvents(pageable, status);
        return ResponseEntity.ok(events);
    }

    @PostMapping("/{eventId}/register")
    public ResponseEntity<?> registerForEvent(@PathVariable Long eventId, Authentication authentication) {
        try {
            Long studentId = getUserIdFromAuthentication(authentication);
            String qrCodeBase64 = eventService.registerForEvent(eventId, studentId);
            return ResponseEntity.ok(qrCodeBase64);
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    @DeleteMapping("/{eventId}/register")
    public ResponseEntity<?> cancelRegistration(@PathVariable Long eventId, Authentication authentication) {
        try {
            Long studentId = getUserIdFromAuthentication(authentication);
            eventService.cancelRegistration(eventId, studentId);
            return ResponseEntity.noContent().build();
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    @GetMapping("/{eventId}/join")
    public ResponseEntity<?> joinOnlineEvent(@PathVariable Long eventId, Authentication authentication) {
        try {
            Long studentId = getUserIdFromAuthentication(authentication);
            String meetingLink = eventService.joinOnlineEvent(eventId, studentId);

            Event event = eventRepository.findById(eventId)
                    .orElseThrow(() -> new IllegalStateException("Event not found with id: " + eventId));

            String username = authentication.getName();
            String roomId = meetingLink.replace("room://", "");
            String meetingToken = hmsTokenService.generateHmsToken(roomId, username, "student");

            Map<String, String> response = new HashMap<>();
            response.put("meetingLink", meetingLink);
            response.put("meetingToken", meetingToken);
            response.put("roomId", roomId);
            response.put("title", event.getTitle());

            return ResponseEntity.ok(response);
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    @PostMapping("/{eventId}/check-in")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> validateQRCode(@PathVariable Long eventId, @RequestBody Map<String, Long> qrData) {
        try {
            // Validate that the QR data contains the required fields
            if (!qrData.containsKey("eventId") || !qrData.containsKey("studentId")) {
                return buildErrorResponse(HttpStatus.BAD_REQUEST, "Invalid QR code data: eventId and studentId are required");
            }

            // Convert the QR data to a JSON string for parsing in the service
            String qrDataJson = "{\"eventId\":" + qrData.get("eventId") + ",\"studentId\":" + qrData.get("studentId") + "}";
            boolean checkedIn = eventService.validateQRCode(eventId, qrDataJson);
            return ResponseEntity.ok(checkedIn);
        } catch (Exception e) {
            return buildErrorResponse(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred: " + e.getMessage());
        }
    }

    @GetMapping("/my-events")
    public ResponseEntity<List<EventDTO>> getMyRegisteredEvents(Authentication authentication) {
        Long studentId = getUserIdFromAuthentication(authentication);
        List<EventDTO> events = eventService.getMyRegisteredEvents(studentId);
        return ResponseEntity.ok(events);
    }

    @GetMapping("/{eventId}/attendance")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> exportAttendance(@PathVariable Long eventId, Authentication authentication) {
        try {
            Long adminId = getUserIdFromAuthentication(authentication);
            List<AttendanceDTO> attendance = eventService.exportAttendance(eventId, adminId);
            return ResponseEntity.ok(attendance);
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    @GetMapping("/{eventId}/attendance/csv")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> exportAttendanceCSV(@PathVariable Long eventId, Authentication authentication) {
        try {
            Long adminId = getUserIdFromAuthentication(authentication);
            String csvBase64 = eventService.exportAttendanceCSV(eventId, adminId);
            return ResponseEntity.ok(csvBase64);
        } catch (EventServiceException e) {
            return buildErrorResponse(e.getStatus(), e.getMessage());
        }
    }

    private Long getUserIdFromAuthentication(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalStateException("User is not authenticated");
        }
        String username = authentication.getName();
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("User not found: " + username));
        return user.getId();
    }

    private ResponseEntity<Map<String, String>> buildErrorResponse(HttpStatus status, String message) {
        Map<String, String> errorResponse = new HashMap<>();
        errorResponse.put("message", message);
        return new ResponseEntity<>(errorResponse, status);
    }
}