package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.dto.LessonProgressDTO;
import project.models.*;
import project.repository.EnrollmentRepository;
import project.repository.LessonProgressRepository;
import project.repository.LessonRepository;
import project.exception.ResourceNotFoundException;

import javax.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class LessonProgressService {

    @Autowired
    private LessonProgressRepository lessonProgressRepository;

    @Autowired
    private EnrollmentRepository enrollmentRepository;

    @Autowired
    private LessonRepository lessonRepository;

    public boolean isUserEnrolledInCourse(Long userId, Long enrollmentId) {
        return enrollmentRepository.existsByIdAndStudentId(enrollmentId, userId);
    }

    @Transactional
    public LessonProgressDTO markLessonAsCompleted(Long enrollmentId, Long lessonId) {
        Enrollment enrollment = enrollmentRepository.findById(enrollmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found"));

        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new ResourceNotFoundException("Lesson not found"));

        if (!enrollment.getCourse().getId().equals(lesson.getCourse().getId())) {
            throw new IllegalArgumentException("Lesson does not belong to the enrolled course");
        }

        LessonProgress lessonProgress = lessonProgressRepository
                .findByEnrollmentAndLesson(enrollment, lesson)
                .orElse(new LessonProgress());

        lessonProgress.setEnrollment(enrollment);
        lessonProgress.setLesson(lesson);
        lessonProgress.setStatus(LessonProgress.LessonStatus.COMPLETED);
        lessonProgress.setCompletedAt(LocalDateTime.now());

        lessonProgress = lessonProgressRepository.save(lessonProgress);

        updateCourseProgress(enrollment);

        return LessonProgressDTO.fromEntity(lessonProgress);
    }

    public int getCourseProgress(Long enrollmentId) {
        Enrollment enrollment = enrollmentRepository.findById(enrollmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Enrollment not found"));
        return enrollment.getProgressPercentage();
    }

    private void updateCourseProgress(Enrollment enrollment) {
        List<LessonProgress> completedLessons = lessonProgressRepository.findByEnrollment(enrollment);
        int totalLessons = enrollment.getCourse().getLessons().size();
        int completedLessonsCount = (int) completedLessons.stream()
                .filter(lp -> lp.getStatus() == LessonProgress.LessonStatus.COMPLETED)
                .count();

        int progressPercentage = (int) ((double) completedLessonsCount / totalLessons * 100);
        enrollment.setProgressPercentage(progressPercentage);

        if (progressPercentage == 100) {
            enrollment.setStatus(EnrollmentStatus.COMPLETED);
        }

        enrollmentRepository.save(enrollment);
    }
}