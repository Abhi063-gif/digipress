-- ============================================================
--  DigiPress Database Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS digipress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE digipress;

-- ── Users ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id              INT          AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    email           VARCHAR(191) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    role            ENUM('admin','user') NOT NULL DEFAULT 'user',
    otp_code        VARCHAR(6)   DEFAULT NULL,
    otp_expires_at  DATETIME     DEFAULT NULL,
    email_verified  TINYINT(1)   NOT NULL DEFAULT 0,
    fcm_token       TEXT         DEFAULT NULL,
    user_type       ENUM('student', 'teacher') DEFAULT NULL,
    department      VARCHAR(100) DEFAULT NULL,
    class_name      VARCHAR(100) DEFAULT NULL,
    roll_number     VARCHAR(50)  DEFAULT NULL,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Seed the admin account (password: Abhi@123  →  bcrypt hash shown below)
-- Run: php -r "echo password_hash('Abhi@123', PASSWORD_BCRYPT);"
INSERT IGNORE INTO users (name, email, password_hash, role, email_verified)
VALUES (
    'Admin',
    'a4abhi078@gmail.com',
    '$2y$10$TKh8H1.PfuKNJZMT8iV7.OcJy6OtP3z2/S7u3Y0IYh9y5b5YvpVNm', -- bcrypt hash of: Abhi@123
    'admin',
    1
);

-- ── Categories ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
    id         INT          AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(80)  NOT NULL UNIQUE,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO categories (name) VALUES
    ('Magazine'), ('Prospectus'), ('Notice'), ('Syllabus'), ('Research');

-- ── Publications (PDFs) ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS publications (
    id              INT          AUTO_INCREMENT PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    description     TEXT         DEFAULT NULL,
    category_id     INT          NOT NULL,
    pdf_url         TEXT         NOT NULL,   -- Cloudinary secure URL
    cloudinary_id   VARCHAR(255) NOT NULL,   -- public_id for deletion
    cover_url       TEXT         DEFAULT NULL,
    pages           INT          DEFAULT 0,
    uploaded_by     INT          NOT NULL,   -- users.id
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id)  REFERENCES categories(id)  ON DELETE RESTRICT,
    FOREIGN KEY (uploaded_by)  REFERENCES users(id)       ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Notifications ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id           INT          AUTO_INCREMENT PRIMARY KEY,
    title        VARCHAR(255) NOT NULL,
    body         TEXT         NOT NULL,
    category     VARCHAR(80)  DEFAULT NULL,
    pub_id       INT          DEFAULT NULL,   -- publications.id (nullable)
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pub_id) REFERENCES publications(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ── Notification Read Receipts ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notification_reads (
    id              INT  AUTO_INCREMENT PRIMARY KEY,
    notification_id INT  NOT NULL,
    user_id         INT  NOT NULL,
    read_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_notif_user (notification_id, user_id),
    FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)         REFERENCES users(id)         ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── Reading History ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reading_history (
    id              INT  AUTO_INCREMENT PRIMARY KEY,
    user_id         INT  NOT NULL,
    pub_id          INT  NOT NULL,
    last_read_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_history_user_pub (user_id, pub_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (pub_id)  REFERENCES publications(id) ON DELETE CASCADE
) ENGINE=InnoDB;
