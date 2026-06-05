<?php
/**
 * POST /api/user/saveDownload.php
 * Header: Authorization: Bearer <token>
 * Body: { "pub_id": 123, "timestamp": "2026-04-28 10:00:00" } (optional timestamp)
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
    INSERT INTO downloads (user_id, pub_id, downloaded_at)
    VALUES (?, ?, NOW())
    ON DUPLICATE KEY UPDATE downloaded_at = NOW()
');
$stmt->execute([$userId, $pubId]);

// Increment total download count
$db->prepare('UPDATE publications SET download_count = download_count + 1 WHERE id = ?')->execute([$pubId]);

jsonSuccess(['message' => 'Download saved successfully.']);
