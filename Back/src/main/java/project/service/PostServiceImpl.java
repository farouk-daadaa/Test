package project.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import project.models.PostEntity;
import project.repository.PostRepository;

import java.util.Date;
import java.util.List;

@Service
public class PostServiceImpl implements PostServiceInter{

    @Autowired
    private PostRepository postRepository;
    @Override
    public PostEntity createPost(PostEntity post){
        post.setCreated(new Date());
        return postRepository.save(post);
    }

    @Override
    public List<PostEntity> getAllPosts(){
        return postRepository.findAll();
    }
}
