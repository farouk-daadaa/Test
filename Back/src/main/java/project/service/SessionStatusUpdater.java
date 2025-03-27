package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import project.models.Session;
import project.repository.SessionRepository;

import java.util.List;

@Component
public class SessionStatusUpdater {

    @Autowired
    private SessionRepository sessionRepository;

    // Runs every 5 minutes (300,000 ms = 5 minutes)
    @Scheduled(fixedRate = 300000)
    public void updateSessionStatuses() {
        List<Session> sessions = sessionRepository.findAll();
        for (Session session : sessions) {
            Session.SessionStatus currentStatus = session.getStatus(); // Current persisted status
            session.updateStatus(); // Recalculate based on current time
            if (session.getStatus() != currentStatus) {
                sessionRepository.save(session); // Save only if status changed
            }
        }
    }
}