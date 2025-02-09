package project.security;


import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import project.models.InstructorStatus;
import project.models.UserRole;
import project.models.UserEntity;
import project.repository.UserRepository;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.stream.Collectors;


@Service
public class CustomUserDetailsService implements UserDetailsService {

    private UserRepository userRepository;

    @Autowired
    public CustomUserDetailsService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        UserEntity user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("Username not found"));

        // Check if the user is an instructor and their status is approved
        if (user.getUserRole().getUserRoleName().toString().equals("INSTRUCTOR") &&
                (user.getInstructor() == null || user.getInstructor().getStatus() != InstructorStatus.APPROVED)) {
            throw new UsernameNotFoundException("Instructor not approved");
        }

        return new User(user.getUsername(), user.getPassword(), mapRolesToAuthorities(user.getUserRole()));
    }

    private Collection<GrantedAuthority> mapRolesToAuthorities(UserRole userRole) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        authorities.add(new SimpleGrantedAuthority("ROLE_" + userRole.getUserRoleName().toString()));
        return authorities;
    }
}
