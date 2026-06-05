<?php
/**
 * GET /api/notifications/list.php
 * Header: Authorization: Bearer <token>
 * Returns notifications for the authenticated user,
 * with read/unread status.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];

$db = getDB();
$sql = "SELECT n.id, n.title, n.body, n.category, n.pub_id, n.created_at,
               p.pdf_url,
               CASE WHEN nr.id IS NOT NULL THEN 1 ELSE 0 END AS is_read
        FROM notifications n
        LEFT JOIN publications p ON p.id = n.pub_id
        LEFT JOIN notification_reads nr ON nr.notification_id = n.id AND nr.user_id = ?
        WHERE n.id NOT IN (SELECT notification_id FROM notification_deletes WHERE user_id = ?)
        ORDER BY n.created_at DESC
        LIMIT 50";
$stmt = $db->prepare($sql);
$stmt->execute([$userId, $userId]);

$notifications = $stmt->fetchAll();

// Count unread
$unread = 0;
foreach ($notifications as &$n) {
    $n['is_read'] = (bool) $n['is_read'];
    if (!$n['is_read']) $unread++;
}

jsonSuccess([
    'notifications' => $notifications,
    'unread_count'  => $unread,
]);
