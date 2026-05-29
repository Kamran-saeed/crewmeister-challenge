package com.crewmeister.crewmeisterchallenge.repository;

import com.crewmeister.crewmeisterchallenge.model.User;
import org.springframework.data.repository.Repository;

//create user repository
public interface UserRepository extends Repository<User, Long> {
  User save(User user);

  User findById(Long id);
}