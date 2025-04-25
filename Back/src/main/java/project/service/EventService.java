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
import org.springframework.web.multipart.MultipartFile;
import project.dto.AttendanceDTO;
import project.dto.EventDTO;
import project.exception.EventServiceException;
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
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
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

    @Value("${event.reminder.hours-before}")
    private String reminderHoursBefore;

    private final RestTemplate restTemplate = new RestTemplate();

    private final Map<String, LocalDateTime> recentCheckIns = new ConcurrentHashMap<>();
    private static final long CHECK_IN_COOLDOWN_SECONDS = 30;

    private static final String UPLOAD_DIR = "uploads/event-images/";

    @Transactional
    public EventDTO createEvent(@Valid EventDTO eventDTO, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new EventServiceException(HttpStatus.FORBIDDEN, "Only admins can create events");
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

        return EventDTO.fromEntity(savedEvent, eventRegistrationRepository, eventRepository);
    }

    @Transactional
    public EventDTO updateEvent(@Valid EventDTO eventDTO, Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new EventServiceException(HttpStatus.FORBIDDEN, "Only admins can update events");
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

        return EventDTO.fromEntity(updatedEvent, eventRegistrationRepository, eventRepository);
    }

    @Transactional
    public void deleteEvent(Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new EventServiceException(HttpStatus.FORBIDDEN, "Only admins can delete events");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));

        if (event.getStatus() == Event.EventStatus.ONGOING) {
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "Cannot delete an ongoing event");
        }

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
        logger.info("Event {} deleted by admin {}", eventId, adminId);
    }

    @Scheduled(cron = "0 0 * * * *")
    @Transactional
    public void sendEventReminders() {
        logger.info("Running sendEventReminders at {}", LocalDateTime.now());
        LocalDateTime now = LocalDateTime.now();

        List<Integer> reminderIntervals = Arrays.stream(reminderHoursBefore.split(","))
                .map(Integer::parseInt)
                .collect(Collectors.toList());

        for (Integer hoursBefore : reminderIntervals) {
            LocalDateTime startWindow = now.plusHours(hoursBefore - 1);
            LocalDateTime endWindow = now.plusHours(hoursBefore + 1);

            List<Event> upcomingEvents = eventRepository.findByStartDateTimeBetween(startWindow, endWindow);
            logger.info("Found {} upcoming events between {} and {} for {} hours reminder",
                    upcomingEvents.size(), startWindow, endWindow, hoursBefore);

            for (Event event : upcomingEvents) {
                String reminderKey = event.getId() + "-" + hoursBefore;
                if (eventReminderRepository.existsByEventIdAndHoursBefore(event.getId(), hoursBefore)) {
                    logger.info("Reminder for {} hours already sent for event ID: {}", hoursBefore, event.getId());
                    continue;
                }

                List<Long> registeredUserIds = eventRegistrationRepository.findAllByEvent(event)
                        .stream()
                        .map(reg -> reg.getStudent().getId())
                        .collect(Collectors.toList());

                if (!registeredUserIds.isEmpty()) {
                    String notificationTitle = "Reminder: " + event.getTitle() + " in " + hoursBefore + " Hours";
                    String notificationMessage = "The event '" + event.getTitle() + "' is in " + hoursBefore + " hours at " +
                            event.getStartDateTime() + ". " +
                            (event.isOnline() ? "Join online: " + event.getMeetingLink() : "Location: " + event.getLocation()) +
                            " [Event ID: " + event.getId() + "]";
                    logger.info("Sending reminder for event ID: {} to {} users for {} hours", event.getId(), registeredUserIds.size(), hoursBefore);
                    notificationService.createNotificationsWithPagination(
                            registeredUserIds,
                            notificationTitle,
                            notificationMessage,
                            Notification.NotificationType.EVENT,
                            UserRoleName.USER
                    );

                    EventReminder reminder = new EventReminder();
                    reminder.setEventId(event.getId());
                    reminder.setHoursBefore(hoursBefore);
                    reminder.setSentAt(now);
                    eventReminderRepository.save(reminder);
                    logger.info("Saved reminder for event ID: {} for {} hours", event.getId(), hoursBefore);
                } else {
                    logger.info("No registered users for event ID: {}", event.getId());
                }
            }
        }
    }

    @Scheduled(cron = "0 * * * * *")
    @Transactional
    public void updateEventStatuses() {
        logger.info("Running updateEventStatuses at {}", LocalDateTime.now());
        LocalDateTime now = LocalDateTime.now();

        List<Event> eventsToUpdate = eventRepository.findAll().stream()
                .filter(event -> event.getStatus() != Event.EventStatus.ENDED)
                .collect(Collectors.toList());

        logger.info("Found {} events to update (excluding ENDED events)", eventsToUpdate.size());
        for (Event event : eventsToUpdate) {
            event = eventRepository.findById(event.getId()).orElse(event);

            logger.info("Processing event ID {}: title={}, startDateTime={}, endDateTime={}, currentStatus={}",
                    event.getId(), event.getTitle(), event.getStartDateTime(), event.getEndDateTime(), event.getStatus());

            Event.EventStatus oldStatus = event.getStatus();
            event.updateStatus();
            Event savedEvent = eventRepository.save(event);
            Event.EventStatus newStatus = savedEvent.getStatus();

            Event refreshedEvent = eventRepository.findById(event.getId()).orElse(event);
            logger.info("Database status for event ID {} after save: {}", event.getId(), refreshedEvent.getStatus());

            if (oldStatus != newStatus) {
                logger.info("Event ID {} status changed from {} to {}", event.getId(), oldStatus, newStatus);

                if (newStatus == Event.EventStatus.ONGOING || newStatus == Event.EventStatus.ENDED) {
                    List<Long> registeredUserIds = eventRegistrationRepository.findAllByEvent(event)
                            .stream()
                            .map(reg -> reg.getStudent().getId())
                            .collect(Collectors.toList());

                    if (!registeredUserIds.isEmpty()) {
                        String notificationTitle = "Event Status Update: " + event.getTitle();
                        String notificationMessage = "The event '" + event.getTitle() + "' is now " + newStatus + ". " +
                                (event.isOnline() ? "Join online: " + event.getMeetingLink() : "Location: " + event.getLocation()) +
                                " [Event ID: " + event.getId() + "]";
                        notificationService.createNotificationsWithPagination(
                                registeredUserIds,
                                notificationTitle,
                                notificationMessage,
                                Notification.NotificationType.EVENT,
                                UserRoleName.USER
                        );
                    }
                }
            } else {
                logger.info("Event ID {} status unchanged: {}", event.getId(), newStatus);
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
            throw new EventServiceException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to create 100ms room: " + response.getBody());
        }

        Map responseBody = response.getBody();
        if (responseBody == null || !responseBody.containsKey("id") || responseBody.get("id") == null) {
            throw new EventServiceException(HttpStatus.INTERNAL_SERVER_ERROR, "HMS room creation response missing 'id' field");
        }

        return (String) responseBody.get("id");
    }

    public Page<EventDTO> getAllEvents(Pageable pageable, String statusFilter) {
        Event.EventStatus status = statusFilter != null && !statusFilter.isEmpty()
                ? Event.EventStatus.valueOf(statusFilter.toUpperCase())
                : null;
        return eventRepository.findByStatus(status, pageable)
                .map(event -> EventDTO.fromEntity(event, eventRegistrationRepository, eventRepository));
    }

    @Transactional
    public String registerForEvent(Long eventId, Long userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

        if (event.getStatus() != Event.EventStatus.UPCOMING) {
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "Cannot register for an event that is not upcoming");
        }

        if (eventRegistrationRepository.existsByEventAndStudent(event, user)) {
            throw new EventServiceException(HttpStatus.CONFLICT, "You are already registered for this event");
        }

        if (event.getMaxParticipants() != null && event.getRegistrations().size() >= event.getMaxParticipants()) {
            throw new EventServiceException(HttpStatus.CONFLICT, "Event has reached maximum participants");
        }

        EventRegistration registration = new EventRegistration();
        registration.setEvent(event);
        registration.setStudent(user);
        registration.setCheckedIn(false);
        eventRegistrationRepository.save(registration);
        logger.info("User {} registered for event {}", userId, eventId);

        if (!event.isOnline()) {
            try {
                String qrCode = QRCodeUtil.generateQRCodeBase64(eventId, userId);
                logger.info("Generated QR code for user {} at event {}", userId, eventId);
                return qrCode;
            } catch (Exception e) {
                throw new EventServiceException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to generate QR code: " + e.getMessage());
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
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "This is not an online event");
        }

        // Skip registration check for admins
        boolean isAdmin = user.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN);
        if (!isAdmin && !eventRegistrationRepository.existsByEventAndStudent(event, user)) {
            throw new EventServiceException(HttpStatus.FORBIDDEN, "You are not registered for this event");
        }

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = event.getStartDateTime().minusMinutes(10);
        if (now.isBefore(windowStart) || now.isAfter(event.getEndDateTime())) {
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "You can only join the event from 10 minutes before start until the end");
        }

        logger.info("User {} joined online event {}", userId, eventId);
        return event.getMeetingLink();
    }

    @Transactional
    public boolean validateQRCode(Long eventId, String qrData) {
        try {
            Map<String, Long> qrInfo = QRCodeUtil.parseQRCodeData(qrData);
            Long qrEventId = qrInfo.get("eventId");
            Long userId = qrInfo.get("studentId");

            String checkInKey = eventId + ":" + userId;
            LocalDateTime now = LocalDateTime.now();
            LocalDateTime lastCheckIn = recentCheckIns.get(checkInKey);
            if (lastCheckIn != null && now.isBefore(lastCheckIn.plusSeconds(CHECK_IN_COOLDOWN_SECONDS))) {
                logger.warn("Duplicate check-in attempt for user {} at event {} within cooldown period", userId, eventId);
                return false;
            }

            if (!qrEventId.equals(eventId)) {
                logger.warn("QR code eventId {} does not match endpoint eventId {}", qrEventId, eventId);
                return false;
            }

            Event event = eventRepository.findById(eventId)
                    .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
            UserEntity user = userRepository.findById(userId)
                    .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

            LocalDateTime windowStart = event.getStartDateTime().minusMinutes(10);
            if (now.isBefore(windowStart) || now.isAfter(event.getEndDateTime())) {
                logger.warn("Check-in attempted outside allowed window for eventId {} at {}", eventId, now);
                return false;
            }

            EventRegistration registration = eventRegistrationRepository.findByEventAndStudent(event, user)
                    .orElse(null);
            if (registration == null) {
                logger.warn("User {} is not registered for event {}", userId, eventId);
                return false;
            }

            if (registration.isCheckedIn()) {
                logger.warn("User {} has already checked in for event {}", userId, eventId);
                return false;
            }

            registration.setCheckedIn(true);
            registration.setCheckInTime(now);
            eventRegistrationRepository.save(registration);
            recentCheckIns.put(checkInKey, now);
            logger.info("Successful check-in for user {} at event {}", userId, eventId);
            return true;
        } catch (InvalidQRCodeException | IOException e) {
            logger.error("Failed to validate QR code: {}", e.getMessage());
            return false;
        }
    }

    @Scheduled(fixedRate = 60000)
    public void cleanUpRecentCheckIns() {
        LocalDateTime now = LocalDateTime.now();
        recentCheckIns.entrySet().removeIf(entry ->
                now.isAfter(entry.getValue().plusSeconds(CHECK_IN_COOLDOWN_SECONDS)));
    }

    public List<EventDTO> getMyRegisteredEvents(Long userId) {
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));
        return eventRegistrationRepository.findByStudent(user).stream()
                .map(reg -> EventDTO.fromEntity(reg.getEvent(), eventRegistrationRepository, eventRepository))
                .collect(Collectors.toList());
    }

    public List<AttendanceDTO> exportAttendance(Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new EventServiceException(HttpStatus.FORBIDDEN, "Only admins can export attendance");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        if (event.isOnline()) {
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "Attendance export is only available for in-person events");
        }

        return eventRegistrationRepository.findAllByEvent(event).stream()
                .map(reg -> new AttendanceDTO(
                        reg.getStudent().getId(),
                        reg.getStudent().getUsername(),
                        reg.isCheckedIn(),
                        reg.getCheckInTime()))
                .collect(Collectors.toList());
    }

    public String exportAttendanceCSV(Long eventId, Long adminId) {
        UserEntity admin = userRepository.findById(adminId)
                .orElseThrow(() -> new ResourceNotFoundException("Admin not found with id: " + adminId));
        if (!admin.getUserRole().getUserRoleName().equals(UserRoleName.ADMIN)) {
            throw new EventServiceException(HttpStatus.FORBIDDEN, "Only admins can export attendance");
        }

        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        if (event.isOnline()) {
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "Attendance export is only available for in-person events");
        }

        List<AttendanceDTO> attendance = eventRegistrationRepository.findAllByEvent(event).stream()
                .map(reg -> new AttendanceDTO(
                        reg.getStudent().getId(),
                        reg.getStudent().getUsername(),
                        reg.isCheckedIn(),
                        reg.getCheckInTime()))
                .collect(Collectors.toList());

        try (ByteArrayOutputStream out = new ByteArrayOutputStream();
             CSVPrinter csvPrinter = new CSVPrinter(new PrintWriter(out), CSVFormat.DEFAULT
                     .withHeader("Student ID", "Username", "Checked In", "Check-In Time"))) {
            for (AttendanceDTO record : attendance) {
                csvPrinter.printRecord(
                        record.getStudentId(),
                        record.getUsername(),
                        record.isCheckedIn(),
                        record.getCheckInTime() != null ? record.getCheckInTime().toString() : null
                );
            }
            csvPrinter.flush();
            return Base64.getEncoder().encodeToString(out.toByteArray());
        } catch (IOException e) {
            throw new EventServiceException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to export CSV: " + e.getMessage());
        }
    }

    @Transactional
    public void cancelRegistration(Long eventId, Long userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with id: " + eventId));
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + userId));

        if (!eventRegistrationRepository.existsByEventAndStudent(event, user)) {
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "You are not registered for this event");
        }

        eventRegistrationRepository.deleteByEventAndStudent(event, user);
        logger.info("User {} cancelled registration for event {}", userId, eventId);
    }

    private void validateEventDates(LocalDateTime start, LocalDateTime end) {
        if (start == null || end == null || !end.isAfter(start)) {
            throw new EventServiceException(HttpStatus.BAD_REQUEST, "End time must be after start time");
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

    public Map<String, String> uploadEventImage(MultipartFile file) {
        try {
            Path uploadPath = Paths.get(UPLOAD_DIR);
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            String originalFilename = file.getOriginalFilename();
            String fileExtension = originalFilename != null && originalFilename.contains(".")
                    ? originalFilename.substring(originalFilename.lastIndexOf("."))
                    : ".jpg";
            String uniqueFilename = UUID.randomUUID().toString() + fileExtension;

            Path filePath = uploadPath.resolve(uniqueFilename);
            Files.write(filePath, file.getBytes());
            logger.info("Event image uploaded successfully: {}", uniqueFilename);

            // Store and return the relative path for both database and frontend
            String relativePath = "/" + UPLOAD_DIR + uniqueFilename;

            Map<String, String> response = new HashMap<>();
            response.put("url", relativePath); // Relative path for frontend to construct full URL
            response.put("relativePath", relativePath); // Relative path for database
            return response;
        } catch (IOException e) {
            logger.error("Failed to upload event image: {}", e.getMessage());
            throw new EventServiceException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to upload event image: " + e.getMessage());
        }
    }
}