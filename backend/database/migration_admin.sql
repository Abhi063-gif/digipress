-- ============================================================
--  DigiPress – Admin Panel Migration
--  Run ONCE via: http://localhost/clg_magzine/database/run_migration.php
-- ============================================================
USE digipress;

-- ── Downloads (per-user, per-publication) ────────────────────
CREATE TABLE IF NOT EXISTS downloads (
    id              INT      AUTO_INCREMENT PRIMARY KEY,
    user_id         INT      NOT NULL,
    pub_id          INT      NOT NULL,
    downloaded_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (pub_id)  REFERENCES publications(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── PDF Views (page opens) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS pdf_views (
    id          INT      AUTO_INCREMENT PRIMARY KEY,
    user_id     INT      DEFAULT NULL,
    pub_id      INT      NOT NULL,
    viewed_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pub_id) REFERENCES publications(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── PDF Shares ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pdf_shares (
    id          INT      AUTO_INCREMENT PRIMARY KEY,
    user_id     INT      DEFAULT NULL,
    pub_id      INT      NOT NULL,
    shared_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pub_id) REFERENCES publications(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ── App Sessions (for avg session time & churn) ──────────────
CREATE TABLE IF NOT EXISTS app_sessions (
    id              INT          AUTO_INCREMENT PRIMARY KEY,
    user_id         INT          NOT NULL,
    session_start   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_end     DATETIME     DEFAULT NULL,
    duration_sec    INT          DEFAULT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
