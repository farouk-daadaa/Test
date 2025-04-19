package project.service;

import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVPrinter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.*;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import project.dto.AttendanceDTO;
import project.dto.EventDTO;
import project.exception.InvalidQRCodeException;
import project.exception.ResourceNotFoundException;
import project.models.*;
import project.repository.EventRegistrationRepository;
import project.repository.EventReminderRepository;
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
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class EventService {

    private static final Logger logger = LoggerFactory.getLogger(EventService.class);

    @Autowired
    private EventRepository eventRepository;

    @Autowired
    private EventRegistrationRepository eventRegistrationRepository;

    @Autowired
    private EventReminderRepository eventReminderRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private NotificationService notificationService;

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

        if (event.isOnline()) {
            String roomId = createHmsRoom(eventDTO.getTitle());
            event.setMeetingLink("room://" + roomId);
        } else {
            event.setMeetingLink(null);
        }

        Event savedEvent = eventRepository.save(event);

        String notificationTitle = "New Event: " + savedEvent.getTitle();
        String notificationMessage = "A new event '" + savedEvent.getTitle() + "' is scheduled for " +
                savedEvent.getStartDateTime() + ". " +
                (savedEvent.isOnline() ? "Join online: " + savedEvent.getMeetingLink() : "Location: " + savedEvent.getLocation()) +
                " [Event ID: " + savedEvent.getId() + "]";
        notificationService.createNotificationsWithPagination(
                Collections.emptyList(),
                notificationTitle,
                notificationMessage,
                Notification.NotificationType.EVENT,
                UserRoleName.USER
        );

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

        if (event.isOnline()) {
            String roomId = createHmsRoom(eventDTO.getTitle());
            event.setMeetingLink("room://" + roomId);
        } else {
            event.setMeetingLink(null);
        }

        Event updatedEvent = eventRepository.save(event);

        List<Long> registeredUserIds = eventRegistrationRepository.findAllByEvent(updatedEvent)
                .stream()
                .map(reg -> reg.getStudent().getId())
                .collect(Collectors.toList());

        if (!registeredUserIds.isEmpty()) {
            String notificationTitle = "Event Updated: " + updatedEvent.getTitle();
            String notificationMessage = "The event '" + updatedEvent.getTitle() + "' has been updated. New details: " +
                    "Start: " + updatedEvent.getStartDateTime() + ", " +
                    (updatedEvent.isOnline() ? "Join online: " + updatedEvent.getMeetingLink() : "Location: " + updatedEvent.getLocation()) +
                    " [Event ID: " + updatedEvent.getId() + "]";
            notificationService.createNotificationsWithPagination(
                    registeredUserIds,
                    notificationTitle,
                    notificationMessage,
                    Notification.NotificationType.EVENT,
                    UserRoleName.USER
            );
        }

        return EventDTO.fromEntity(updatedEvent);
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

        List<Long> registeredUserIds = eventRegistrationRepository.findAllByEvent(event)
                .stream()
                .map(reg -> reg.getStudent().getId())
                .collect(Collectors.toList());

        if (!registeredUserIds.isEmpty()) {
            String notificationTitle = "Event Cancelled: " + event.getTitle();
            String notificationMessage = "The event '" + event.getTitle() + "' scheduled for " +
                    event.getStartDateTime() + " has been cancelled. " +
                    (event.isOnline() ? "Online meeting link is no longer valid." : "Location: " + event.getLocation()) +
                    " [Event ID: " + event.getId() + "]";
            notificationService.createNotificationsWithPagination(
                    registeredUserIds,
                    notificationTitle,
                    notificationMessage,
                    Notification.NotificationType.EVENT,
                    UserRoleName.USER
            );
        }

        eventRepository.delete(event);
    }

    @Scheduled(cron = "0 0 * * * *") // Run every hour
    @Transactional
    public void sendEventReminders() {
        logger.info("Running sendEventReminders at {}", LocalDateTime.now());
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startWindow = now.plusHours(24);
        LocalDateTime endWindow = now.plusHours(25);

        List<Event> upcomingEvents = eventRepository.findByStartDateTimeBetween(startWindow, endWindow);
        logger.info("Found {} upcoming events between {} and {}", upcomingEvents.size(), startWindow, endWindow);

        for (Event event : upcomingEvents) {
            if (eventReminderRepository.existsByEventId(event.getId())) {
                logger.info("Reminder already sent for event ID: {}", event.getId());
                continue;
            }

            List<Long> registeredUserIds = eventRegistrationRepository.findAllByEvent(event)
                    .stream()
                    .map(reg -> reg.getStudent().getId())
                    .collect(Collectors.toList());

            if (!registeredUserIds.isEmpty()) {
                String notificationTitle = "Reminder: " + event.getTitle() + " Tomorrow";
                String notificationMessage = "The event '" + event.getTitle() + "' is tomorrow at " +
                        event.getStartDateTime() + ". " +
                        (event.isOnline() ? "Join online: " + event.getMeetingLink() : "Location: " + event.getLocation()) +
                        " [Event ID: " + event.getId() + "]";
                logger.info("Sending reminder for event ID: {} to {} users", event.getId(), registeredUserIds.size());
                notificationService.createNotificationsWithPagination(
                        registeredUserIds,
                        notificationTitle,
                        notificationMessage,
                        Notification.NotificationType.EVENT,
                        UserRoleName.USER
                );

                EventReminder reminder = new EventReminder();
                reminder.setEventId(event.getId());
                reminder.setSentAt(now);
                eventReminderRepository.save(reminder);
                logger.info("Saved reminder for event ID: {}", event.getId());
            } else {
                logger.info("No registered users for event ID: {}", event.getId());
            }
        }
    }

    private String createHmsRoom(String eventTitle) {
        Map<String, String> body = new HashMap<>();
        body.put("name", "event-" + eventTitle + "-" + System.currentTimeMillis());
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

        return (String) response.getBody().get("id");
    }

    public Page<EventDTO> getAllEvents(Pageable pageable, String statusFilter) {
        Event.EventStatus status = statusFilter != null && !statusFilter.isEmpty()
                ? Event.EventStatus.valueOf(statusFilter.toUpperCase())
                : null;
        return eventRepository.findByStatus(status, pageable)
                .map(EventDTO::fromEntity);
    }

    @Transactional
    public String registerForEvent(Long eventId, Long userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

        if (eventRegistrationRepository.existsByEventAndStudent(event, user)) {
            throw new IllegalStateException("You are already registered for this event");
        }

        if (event.getMaxParticipants() != null && event.getRegistrations().size() >= event.getMaxParticipants()) {
            throw new IllegalStateException("Event has reached maximum participants");
        }

        EventRegistration registration = new EventRegistration();
        registration.setEvent(event);
        registration.setStudent(user);
        registration.setCheckedIn(false);
        eventRegistrationRepository.save(registration);

        if (!event.isOnline()) {
            try {
                return QRCodeUtil.generateQRCodeBase64(eventId, userId);
            } catch (Exception e) {
                throw new RuntimeException("Failed to generate QR code: " + e.getMessage());
            }
        }
        return null;
    }

    public String joinOnlineEvent(Long eventId, Long userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

        if (!event.isOnline()) {
            throw new IllegalStateException("This is not an online event");
        }

        if (!eventRegistrationRepository.existsByEventAndStudent(event, user)) {
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
            Long userId = qrInfo.get("studentId");

            Event event = eventRepository.findById(eventId)
                    .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
            UserEntity user = userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

            EventRegistration registration = eventRegistrationRepository.findByEventAndStudent(event, user)
                    .orElseThrow(() -> new IllegalStateException("User is not registered for this event"));

            if (registration.isCheckedIn()) {
                throw new IllegalStateException("User has already checked in");
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

    public List<EventDTO> getMyRegisteredEvents(Long userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
        return eventRegistrationRepository.findByStudent(user).stream()
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
    public void cancelRegistration(Long eventId, Long userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

        if (!eventRegistrationRepository.existsByEventAndStudent(event, user)) {
            throw new IllegalStateException("You are not registered for this event");
        }

        eventRegistrationRepository.deleteByEventAndStudent(event, user);
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