package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import project.dto.CourseCategoryDTO;
import project.models.CourseCategory;
import project.service.CourseCategoryService;

import javax.validation.Valid;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/categories")
public class CourseCategoryController {

    @Autowired
    private CourseCategoryService courseCategoryService;

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CourseCategoryDTO> createCategory(@Valid @RequestBody CourseCategory category) {
        CourseCategory createdCategory = courseCategoryService.createCategory(category);
        return new ResponseEntity<>(CourseCategoryDTO.fromEntity(createdCategory), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CourseCategoryDTO> updateCategory(@PathVariable Long id, @Valid @RequestBody CourseCategory category) {
        CourseCategory updatedCategory = courseCategoryService.updateCategory(id, category);
        return ResponseEntity.ok(CourseCategoryDTO.fromEntity(updatedCategory));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> deleteCategory(@PathVariable Long id) {
        courseCategoryService.deleteCategory(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}")
    public ResponseEntity<CourseCategoryDTO> getCategory(@PathVariable Long id) {
        CourseCategory category = courseCategoryService.getCategoryById(id);
        return ResponseEntity.ok(CourseCategoryDTO.fromEntity(category));
    }

    @GetMapping
    public ResponseEntity<List<CourseCategoryDTO>> getAllCategories() {
        List<CourseCategoryDTO> categories = courseCategoryService.getAllCategories()
                .stream()
                .map(CourseCategoryDTO::fromEntity)
                .collect(Collectors.toList());
        return ResponseEntity.ok(categories);
    }
}