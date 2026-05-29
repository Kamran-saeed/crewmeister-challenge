package com.crewmeister.crewmeisterchallenge.controller;

import com.crewmeister.crewmeisterchallenge.model.User;
import com.crewmeister.crewmeisterchallenge.repository.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserController {

  UserRepository userRepository;

  public UserController(UserRepository userRepository) {
    this.userRepository = userRepository;
  }

  @GetMapping( "/user")
  public String hello(@RequestParam Long id) {
    // get user from database
    User user = userRepository.findById(id);
    return "Greetings from Crewmeister, " + user.getName() + "!";
  }

  @PostMapping( "/user")
  public String helloPost(@RequestBody String body) {
    try {
      // Parse JSON string to get name
      ObjectMapper objectMapper = new ObjectMapper();
      JsonNode jsonNode = objectMapper.readTree(body);
      String name = jsonNode.get("name").asText();

      // Save user to database
      User user = new User();
      user.setName(name);
      User returnedUser = userRepository.save(user);

      return "Greetings from Crewmeister, " + returnedUser.getName() + "!";
    } catch (Exception e) {
      e.printStackTrace();
      return "Error parsing JSON";
    }
  }

}
