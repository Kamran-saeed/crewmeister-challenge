CREATE TABLE user (
  id bigint(20) NOT NULL AUTO_INCREMENT,
name varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO user (id, name) VALUES (1, 'Alice');