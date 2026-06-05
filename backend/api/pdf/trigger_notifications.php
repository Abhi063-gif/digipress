<?php
/**
 * POST /api/pdf/trigger_notifications.php
 * Triggers notification records and FCM broadcasts for a new publication.
 * Called asynchronously by the app to prevent upload hangs.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';
require_once __DIR__ . '/../../helpers/send_notification.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

// Admin only
$auth = requireAdmin();

$body = getJsonBody();
$pubId = (int) ($body['pub_id'] ?? 0);

if (!$pubId) jsonError('Publication ID required.');

$db = getDB();

// Fetch pub info
$stmt = $db->prepare('
    SELECT p.title, c.name as cat_name 
    FROM publications p 
    JOIN categories c ON c.id = p.category_id 
    WHERE p.id = ?
');
$stmt->execute([$pubId]);
$pub = $stmt->fetch();

if (!$pub) jsonError('Publication not found.');

$title   = $pub['title'];
$catName = $pub['cat_name'];

// 1. Create notification record
$db->prepare(
    'INSERT INTO notifications (title, body, category, pub_id) VALUES (?, ?, ?, ?)'
)->execute([
    "$catName: $title",
    "A new $catName has been published. Tap to read.",
    $catName,
    $pubId,
]);

// 2. Broadcast FCM
broadcastNotification(
    "📄 New $catName: $title",
    "A new $catName has just been published on DigiPress. Tap to read it now!",
    ['pub_id' => (string) $pubId, 'type' => 'new_publication']
);

jsonSuccess(['message' => 'Notifications triggered.']);
