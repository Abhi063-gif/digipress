<?php
/**
 * POST /api/notifications/clear.php
 * Header: Authorization: Bearer <token>
 * Marks all notifications as read for the user, effectively "clearing" them.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];

$db = getDB();

// Strategy: Insert into notification_deletes for all existing notifications
// This "hides" them from this user's view.

// Lazy create the table if it doesn't exist
$db->exec("CREATE TABLE IF NOT EXISTS notification_deletes (
    id              INT  AUTO_INCREMENT PRIMARY KEY,
    notification_id INT  NOT NULL,
    user_id         INT  NOT NULL,
    deleted_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_notif_delete_user (notification_id, user_id),
    FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)         REFERENCES users(id)         ON DELETE CASCADE
) ENGINE=InnoDB;");

$sql = "INSERT IGNORE INTO notification_deletes (notification_id, user_id)
        SELECT id, ? FROM notifications";
$stmt = $db->prepare($sql);
$stmt->execute([$userId]);

jsonSuccess(['message' => 'All notifications cleared.']);
