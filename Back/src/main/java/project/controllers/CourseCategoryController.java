package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import project.models.CourseCategory;
import project.service.CourseCategoryService;

import javax.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/api/categories")
public class CourseCategoryController {

    @Autowired
    private CourseCategoryService courseCategoryService;

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CourseCategory> createCategory(@Valid @RequestBody CourseCategory category) {
        CourseCategory createdCategory = courseCategoryService.createCategory(category);
        return new ResponseEntity<>(createdCategory, HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CourseCategory> updateCategory(@PathVariable Long id, @Valid @RequestBody CourseCategory category) {
        CourseCategory updatedCategory = courseCategoryService.updateCategory(id, category);
        return ResponseEntity.ok(updatedCategory);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> deleteCategory(@PathVariable Long id) {
        courseCategoryService.deleteCategory(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}")
    public ResponseEntity<CourseCategory> getCategory(@PathVariable Long id) {
        CourseCategory category = courseCategoryService.getCategoryById(id);
        return ResponseEntity.ok(category);
    }

    @GetMapping
    public ResponseEntity<List<CourseCategory>> getAllCategories() {
        List<CourseCategory> categories = courseCategoryService.getAllCategories();
        return ResponseEntity.ok(categories);
    }
}