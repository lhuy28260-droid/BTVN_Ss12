DROP DATABASE IF EXISTS social_network;
CREATE DATABASE social_network
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE social_network;

CREATE TABLE users (
  user_id    INT          NOT NULL AUTO_INCREMENT,
  username   VARCHAR(50)  NOT NULL,
  password   VARCHAR(255) NOT NULL,
  email      VARCHAR(100) NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_username (username)
) ENGINE=InnoDB;

CREATE TABLE posts (
  post_id    INT      NOT NULL AUTO_INCREMENT,
  user_id    INT      NOT NULL,
  content    TEXT     NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id),
  KEY fk_posts_user (user_id),
  CONSTRAINT fk_posts_user
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE comments (
  comment_id INT      NOT NULL AUTO_INCREMENT,
  post_id    INT      NOT NULL,
  user_id    INT      NOT NULL,
  content    TEXT     NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (comment_id),
  KEY fk_comments_post (post_id),
  KEY fk_comments_user (user_id),
  CONSTRAINT fk_comments_post
    FOREIGN KEY (post_id) REFERENCES posts (post_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_comments_user
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE friends (
  user_id   INT         NOT NULL,
  friend_id INT         NOT NULL,
  status    VARCHAR(20) NOT NULL,
  PRIMARY KEY (user_id, friend_id),
  KEY fk_friends_friend (friend_id),
  CONSTRAINT fk_friends_user
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_friends_friend
    FOREIGN KEY (friend_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_friends_status
    CHECK (status IN ('pending', 'accepted')),
  CONSTRAINT chk_friends_not_self
    CHECK (user_id <> friend_id)
) ENGINE=InnoDB;

CREATE TABLE likes (
  user_id INT NOT NULL,
  post_id INT NOT NULL,
  PRIMARY KEY (user_id, post_id),
  KEY fk_likes_post (post_id),
  CONSTRAINT fk_likes_user
    FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_likes_post
    FOREIGN KEY (post_id) REFERENCES posts (post_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_post_created_at ON posts (created_at);

INSERT INTO users (username, password, email, created_at) VALUES
  ('alice',   '$2a$10$mockhashalice',   'alice@example.com',   '2026-01-10 10:00:00'),
  ('bob',     '$2a$10$mockhashbob',     'bob@example.com',     '2026-01-11 11:00:00'),
  ('charlie', '$2a$10$mockhashcharlie', 'charlie@example.com', '2026-01-12 12:00:00');

INSERT INTO posts (user_id, content, created_at) VALUES
  (1, 'Bài đầu tiên của Alice.', '2026-02-01 09:00:00'),
  (2, 'Bob chia sẻ ảnh cuối tuần.', '2026-02-02 10:30:00'),
  (3, 'Charlie hỏi về học nhóm.', '2026-02-03 08:15:00'),
  (3, 'Bài chưa có tương tác.', '2026-02-05 14:00:00');

INSERT INTO likes (user_id, post_id) VALUES
  (2, 1),
  (3, 1),
  (1, 2),
  (3, 2);

INSERT INTO comments (post_id, user_id, content, created_at) VALUES
  (1, 2, 'Hay quá!', '2026-02-01 10:20:00'),
  (1, 3, 'Đồng ý.', '2026-02-01 10:25:00'),
  (2, 1, 'Đẹp!', '2026-02-02 12:00:00'),
  (3, 1, 'Mình tham gia.', '2026-02-03 09:00:00');

INSERT INTO friends (user_id, friend_id, status) VALUES
  (1, 2, 'accepted'),
  (1, 3, 'accepted'),
  (2, 3, 'accepted');

CREATE OR REPLACE VIEW vw_UserInfo AS
SELECT
  user_id,
  username,
  email,
  created_at
FROM users;

CREATE OR REPLACE VIEW vw_PostStatistics AS
SELECT
  p.post_id,
  p.content      AS noi_dung_bai_viet,
  u.username     AS ten_nguoi_dang,
  COUNT(DISTINCT l.user_id) AS tong_so_like,
  COUNT(DISTINCT c.comment_id)                      AS tong_so_comment
FROM posts p
INNER JOIN users u ON u.user_id = p.user_id
LEFT JOIN likes l ON l.post_id = p.post_id
LEFT JOIN comments c ON c.post_id = p.post_id
GROUP BY
  p.post_id,
  p.user_id,
  p.content,
  u.username;

DELIMITER //

CREATE PROCEDURE sp_add_user (
  IN p_username VARCHAR(50),
  IN p_password VARCHAR(255),
  IN p_email VARCHAR(100)
)
BEGIN
  IF EXISTS (SELECT 1 FROM users u WHERE u.email = p_email) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Email đã được sử dụng';
  END IF;

  INSERT INTO users (username, password, email)
  VALUES (p_username, p_password, p_email);
END//

CREATE PROCEDURE sp_create_post (
  IN  p_user_id INT,
  IN  p_content TEXT,
  OUT p_new_post_id INT
)
BEGIN
  INSERT INTO posts (user_id, content)
  VALUES (p_user_id, p_content);

  SET p_new_post_id = LAST_INSERT_ID();
END//

CREATE PROCEDURE sp_get_friends (
  IN p_user_id INT,
  IN p_limit INT,
  IN p_offset INT
)
BEGIN
  SELECT
    friend.username AS username,
    friend.email    AS email
  FROM friends f
  INNER JOIN users friend ON friend.user_id = CASE
    WHEN f.user_id = p_user_id THEN f.friend_id
    ELSE f.user_id
  END
  WHERE (f.user_id = p_user_id OR f.friend_id = p_user_id)
    AND f.status = 'accepted'
  ORDER BY friend.username ASC, friend.user_id ASC
  LIMIT p_limit OFFSET p_offset;
END//

DELIMITER ;
