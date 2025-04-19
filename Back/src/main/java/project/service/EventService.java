package project.service;

import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVPrinter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import project.dto.AttendanceDTO;
import project.dto.EventDTO;
import project.exception.InvalidQRCodeException;
import project.exception.ResourceNotFoundException;
import project.models.Event;
import project.models.EventRegistration;
import project.models.UserEntity;
import project.models.UserRoleName;
import project.repository.EventRegistrationRepository;
import project.repository.EventRepository;
import project.repository.UserRepository;
import project.utils.QRCodeUtil;

import javax.transaction.Transactional;
import javax.validation.Valid;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class EventService {

    @Autowired
    private EventRepository eventRepository;

    @Autowired
    private EventRegistrationRepository eventRegistrationRepository;

    @Autowired
    private UserRepository userRepository;

    @Value("${hms.room.endpoint}")
    private String HMS_ROOM_ENDPOINT;

    @Value("${hms.template.id}")
    private String HMS_TEMPLATE_ID;

    @Value("${hms.management.token}")
    private String HMS_MANAGEMENT_TOKEN;

    private final RestTemplate restTemplate = new RestTemplate();

    @Transactional
    public EventDTO createEvent(@Valid EventDTO eventDTO, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new IllegalStateException("Only admins can create events");
        }

        validateEventDates(eventDTO.getStartDateTime(), eventDTO.getEndDateTime());
        Event event = new Event();
        mapEventDTOToEntity(eventDTO, event);

        // Generate meeting link for online events
        if (event.isOnline()) {
            String roomId = createHmsRoom(eventDTO.getTitle());
            event.setMeetingLink("room://" + roomId);
        } else {
            event.setMeetingLink(null);
        }

        Event savedEvent = eventRepository.save(event);
        return EventDTO.fromEntity(savedEvent);
    }

    @Transactional
    public EventDTO updateEvent(@Valid EventDTO eventDTO, Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new IllegalStateException("Only admins can update events");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));

        validateEventDates(eventDTO.getStartDateTime(), eventDTO.getEndDateTime());
        mapEventDTOToEntity(eventDTO, event);

        // Update meeting link for online events
        if (event.isOnline()) {
            String roomId = createHmsRoom(eventDTO.getTitle()); // Create new room for simplicity
            event.setMeetingLink("room://" + roomId);
        } else {
            event.setMeetingLink(null);
        }

        Event updatedEvent = eventRepository.save(event);
        return EventDTO.fromEntity(updatedEvent);
    }

    // Helper method to create a room in 100ms
    private String createHmsRoom(String eventTitle) {
        Map<String, String> body = new HashMap<>();
        body.put("name", "event-" + eventTitle + "-" + System.currentTimeMillis()); // Unique name
        body.put("description", "Room for event: " + eventTitle);
        body.put("template_id", HMS_TEMPLATE_ID);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Authorization", "Bearer " + HMS_MANAGEMENT_TOKEN);

        HttpEntity<Map<String, String>> entity = new HttpEntity<>(body, headers);
        ResponseEntity<Map> response = restTemplate.postForEntity(HMS_ROOM_ENDPOINT, entity, Map.class);

        if (response.getStatusCode() != HttpStatus.OK) {
            throw new RuntimeException("Failed to create 100ms room: " + response.getBody());
        }

        return (String) response.getBody().get("id"); // Extract room_id
    }

    @Transactional
    public void deleteEvent(Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new IllegalStateException("Only admins can delete events");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        eventRepository.delete(event);
    }

    public Page<EventDTO> getAllEvents(Pageable pageable, String statusFilter) {
        Event.EventStatus status = statusFilter != null && !statusFilter.isEmpty()
                ? Event.EventStatus.valueOf(statusFilter.toUpperCase())
                : null;
        return eventRepository.findByStatus(status, pageable)
                .map(EventDTO::fromEntity);
    }

    @Transactional
    public String registerForEvent(Long eventId, Long studentId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("Student not found with id: " + studentId));

        if (eventRegistrationRepository.existsByEventAndStudent(event, student)) {
            throw new IllegalStateException("You are already registered for this event");
        }

        if (event.getMaxParticipants() != null && event.getRegistrations().size() >= event.getMaxParticipants()) {
            throw new IllegalStateException("Event has reached maximum participants");
        }

        EventRegistration registration = new EventRegistration();
        registration.setEvent(event);
        registration.setStudent(student);
        registration.setCheckedIn(false);
        eventRegistrationRepository.save(registration);

        if (!event.isOnline()) {
            try {
                return QRCodeUtil.generateQRCodeBase64(eventId, studentId);
            } catch (Exception e) {
                throw new RuntimeException("Failed to generate QR code: " + e.getMessage());
            }
        }
        return null;
    }

    public String joinOnlineEvent(Long eventId, Long studentId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("Student not found with id: " + studentId));

        if (!event.isOnline()) {
            throw new IllegalStateException("This is not an online event");
        }

        if (!eventRegistrationRepository.existsByEventAndStudent(event, student)) {
            throw new IllegalStateException("You are not registered for this event");
        }

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = event.getStartDateTime().minusMinutes(10);
        if (now.isBefore(windowStart) || now.isAfter(event.getEndDateTime())) {
            throw new IllegalStateException("You can only join the event from 10 minutes before start until the end");
        }

        return event.getMeetingLink();
    }

    @Transactional
    public boolean validateQRCode(String qrData) {
        try {
            Map<String, Long> qrInfo = QRCodeUtil.parseQRCodeData(qrData);
            Long eventId = qrInfo.get("eventId");
            Long studentId = qrInfo.get("studentId");

            Event event = eventRepository.findById(eventId)
                    .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
            UserEntity student = userRepository.findById(studentId)
                    .orElseThrow(() -> new ResourceNotFoundException("Student not found with id: " + studentId));

            EventRegistration registration = eventRegistrationRepository.findByEventAndStudent(event, student)
                    .orElseThrow(() -> new IllegalStateException("Student is not registered for this event"));

            if (registration.isCheckedIn()) {
                throw new IllegalStateException("Student has already checked in");
            }

            registration.setCheckedIn(true);
            eventRegistrationRepository.save(registration);
            return true;
        } catch (InvalidQRCodeException e) {
            throw new IllegalStateException("Invalid QR code: " + e.getMessage());
        } catch (IOException e) {
            throw new IllegalStateException("Failed to parse QR code: " + e.getMessage());
        }
    }

    public List<EventDTO> getMyRegisteredEvents(Long studentId) {
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("Student not found with id: " + studentId));
        return eventRegistrationRepository.findByStudent(student).stream()
                .map(reg -> EventDTO.fromEntity(reg.getEvent()))
                .collect(Collectors.toList());
    }

    public List<AttendanceDTO> exportAttendance(Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new IllegalStateException("Only admins can export attendance");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        if (event.isOnline()) {
            throw new IllegalStateException("Attendance export is only available for in-person events");
        }

        return eventRegistrationRepository.findAllByEvent(event).stream()
                .map(reg -> new AttendanceDTO(
                        reg.getStudent().getId(),
                        reg.getStudent().getUsername(),
                        reg.isCheckedIn()))
                .collect(Collectors.toList());
    }

    public String exportAttendanceCSV(Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new IllegalStateException("Only admins can export attendance");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        if (event.isOnline()) {
            throw new IllegalStateException("Attendance export is only available for in-person events");
        }

        List<AttendanceDTO> attendance = eventRegistrationRepository.findAllByEvent(event).stream()
                .map(reg -> new AttendanceDTO(
                        reg.getStudent().getId(),
                        reg.getStudent().getUsername(),
                        reg.isCheckedIn()))
                .collect(Collectors.toList());

        try (ByteArrayOutputStream out = new ByteArrayOutputStream();
             CSVPrinter csvPrinter = new CSVPrinter(new PrintWriter(out), CSVFormat.DEFAULT
                     .withHeader("Student ID", "Username", "Checked In"))) {
            for (AttendanceDTO record : attendance) {
                csvPrinter.printRecord(record.getStudentId(), record.getUsername(), record.isCheckedIn());
            }
            csvPrinter.flush();
            return Base64.getEncoder().encodeToString(out.toByteArray());
        } catch (IOException e) {
            throw new RuntimeException("Failed to export CSV: " + e.getMessage());
        }
    }

    @Transactional
    public void cancelRegistration(Long eventId, Long studentId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity student = userRepository.findById(studentId)
                .orElseThrow(() -> new ResourceNotFoundException("Student not found with id: " + studentId));

        if (!eventRegistrationRepository.existsByEventAndStudent(event, student)) {
            throw new IllegalStateException("You are not registered for this event");
        }

        eventRegistrationRepository.deleteByEventAndStudent(event, student);
    }

    private void validateEventDates(LocalDateTime start, LocalDateTime end) {
        if (start == null || end == null || !end.isAfter(start)) {
            throw new IllegalStateException("End time must be after start time");
        }
    }

    private void mapEventDTOToEntity(EventDTO dto, Event event) {
        event.setTitle(dto.getTitle());
        event.setDescription(dto.getDescription());
        event.setStartDateTime(dto.getStartDateTime());
        event.setEndDateTime(dto.getEndDateTime());
        event.setIsOnline(dto.isOnline());
        event.setLocation(dto.getLocation());
        event.setImageUrl(dto.getImageUrl());
        event.setMaxParticipants(dto.getMaxParticipants());
    }
}