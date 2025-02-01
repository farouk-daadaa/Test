package project.service;

import project.models.PostEntity;

import java.util.List;

public interface PostServiceInter {
    PostEntity createPost(PostEntity post);
    List<PostEntity> getAllPosts();

}
