package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.CourseCategory;
import project.repository.CourseCategoryRepository;
import project.exception.ResourceNotFoundException;

import java.util.List;

@Service
public class CourseCategoryService {

    @Autowired
    private CourseCategoryRepository courseCategoryRepository;

    public CourseCategory createCategory(CourseCategory category) {
        return courseCategoryRepository.save(category);
    }

    public CourseCategory updateCategory(Long id, CourseCategory categoryDetails) {
        CourseCategory category = getCategoryById(id);
        category.setName(categoryDetails.getName());
        return courseCategoryRepository.save(category);
    }

    public void deleteCategory(Long id) {
        CourseCategory category = getCategoryById(id);
        courseCategoryRepository.delete(category);
    }

    public CourseCategory getCategoryById(Long id) {
        return courseCategoryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Category not found with id: " + id));
    }

    public List<CourseCategory> getAllCategories() {
        return courseCategoryRepository.findAll();
    }
}