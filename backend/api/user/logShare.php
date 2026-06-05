<?php
/**
 * POST /api/user/logShare.php
 * Header: Authorization: Bearer <token>
 * Body: { "pub_id": 123 }
 * Logs a share event and increments share_count on publications.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$body  = getJsonBody();
$pubId = (int)($body['pub_id'] ?? 0);
if (!$pubId) jsonError('pub_id is required.', 400);

$userId = null;
$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if ($authHeader) {
    try {
        $auth   = requireAuth();
        $userId = $auth['sub'];
    } catch (Exception $e) { /* anonymous */ }
}

$db = getDB();

$db->prepare('INSERT INTO pdf_shares (user_id, pub_id, shared_at) VALUES (?, ?, NOW())')
   ->execute([$userId, $pubId]);

$db->prepare('UPDATE publications SET share_count = share_count + 1 WHERE id = ?')
   ->execute([$pubId]);

jsonSuccess(['message' => 'Share logged.']);
