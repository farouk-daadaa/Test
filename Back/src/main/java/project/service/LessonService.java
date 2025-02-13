package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.Course;
import project.models.Lesson;
import project.repository.LessonRepository;
import project.exception.ResourceNotFoundException;

@Service
public class LessonService {

    @Autowired
    private LessonRepository lessonRepository;

    @Autowired
    private CourseService courseService;

    public Lesson addLessonToCourse(Long courseId, Lesson lesson) {
        Course course = courseService.getCourseById(courseId);
        lesson.setCourse(course);
        return lessonRepository.save(lesson);
    }

    public Lesson updateLesson(Long courseId, Long lessonId, Lesson lessonDetails) {
        Lesson lesson = getLessonById(courseId, lessonId);
        lesson.setTitle(lessonDetails.getTitle());
        lesson.setDuration(lessonDetails.getDuration());
        lesson.setVideoUrl(lessonDetails.getVideoUrl());
        // Update other fields as necessary
        return lessonRepository.save(lesson);
    }

    public void deleteLesson(Long courseId, Long lessonId) {
        Lesson lesson = getLessonById(courseId, lessonId);
        lessonRepository.delete(lesson);
    }

    public Lesson getLessonById(Long courseId, Long lessonId) {
        Course course = courseService.getCourseById(courseId);
        return lessonRepository.findById(lessonId)
                .filter(lesson -> lesson.getCourse().equals(course))
                .orElseThrow(() -> new ResourceNotFoundException("Lesson not found with id: " + lessonId + " in course: " + courseId));
    }
}

