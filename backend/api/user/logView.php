<?php
/**
 * POST /api/user/logView.php
 * Header: Authorization: Bearer <token>  (optional — views can be anonymous)
 * Body: { "pub_id": 123 }
 * Increments view_count on publications and inserts pdf_views record.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$body  = getJsonBody();
$pubId = (int)($body['pub_id'] ?? 0);
if (!$pubId) jsonError('pub_id is required.', 400);

// Try to get user_id but don't require auth
$userId = null;
$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if ($authHeader) {
    try {
        $auth   = requireAuth();
        $userId = $auth['sub'];
    } catch (Exception $e) { /* anonymous view */ }
}

$db = getDB();

// Insert view record
$db->prepare('INSERT INTO pdf_views (user_id, pub_id, viewed_at) VALUES (?, ?, NOW())')
   ->execute([$userId, $pubId]);

// Increment counter
$db->prepare('UPDATE publications SET view_count = view_count + 1 WHERE id = ?')
   ->execute([$pubId]);

jsonSuccess(['message' => 'View logged.']);
