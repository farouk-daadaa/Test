package project.controllers;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import project.models.PostEntity;
import project.service.PostServiceInter;

import java.util.List;

@RestController
@RequestMapping("/post")
public class PostController {

    @Autowired
    private PostServiceInter postServiceInter;

    @PostMapping("/add")
    public PostEntity createPost(@RequestBody PostEntity post)
    {
        return postServiceInter.createPost(post);
    }

    @GetMapping("/getAll")
    public List<PostEntity> getAllPosts()
    {
        return postServiceInter.getAllPosts();

    }
}
