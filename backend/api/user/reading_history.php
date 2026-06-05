<?php
/**
 * GET /api/user/reading_history.php
 * Header: Authorization: Bearer <token>
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];

$db = getDB();
$stmt = $db->prepare('
    SELECT p.id, p.title, p.pdf_url, p.cover_url, p.created_at, 
           c.name as category, rh.last_read_at
    FROM reading_history rh
    JOIN publications p ON rh.pub_id = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE rh.user_id = ?
    ORDER BY rh.last_read_at DESC
    LIMIT 50
');
$stmt->execute([$userId]);
$history = $stmt->fetchAll();

// Convert numbers
foreach ($history as &$h) {
    $h['id'] = (int) $h['id'];
}

jsonSuccess(['history' => $history]);
