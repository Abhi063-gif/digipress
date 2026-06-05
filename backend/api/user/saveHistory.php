<?php
/**
 * POST /api/user/saveHistory.php
 * Header: Authorization: Bearer <token>
 * Body: { "pub_id": 123 }
 * 
 * Wrapper for log_read.php logic
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];
$body   = getJsonBody();
$pubId  = (int) ($body['pub_id'] ?? 0);

if (!$pubId) jsonError('pub_id is required.', 400);

$db = getDB();

$stmt = $db->prepare('
    INSERT INTO reading_history (user_id, pub_id, last_read_at)
    VALUES (?, ?, NOW())
    ON DUPLICATE KEY UPDATE last_read_at = NOW()
');
$stmt->execute([$userId, $pubId]);

// Also log it as a generic view (for admin stats)
try {
    $db->prepare('INSERT INTO pdf_views (user_id, pub_id, viewed_at) VALUES (?, ?, NOW())')->execute([$userId, $pubId]);
    $db->prepare('UPDATE publications SET view_count = view_count + 1 WHERE id = ?')->execute([$pubId]);
} catch (PDOException $e) {}

jsonSuccess(['message' => 'History saved successfully.']);
