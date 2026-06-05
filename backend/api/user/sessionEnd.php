<?php
/**
 * POST /api/user/sessionEnd.php
 * Body: { "session_id": 123 }
 * Marks the end of an app session and calculates duration.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$auth      = requireAuth();
$userId    = $auth['sub'];
$body      = getJsonBody();
$sessionId = (int)($body['session_id'] ?? 0);

if (!$sessionId) jsonError('session_id is required.', 400);

$db = getDB();
$db->prepare(
    'UPDATE app_sessions
     SET session_end = NOW(),
         duration_sec = TIMESTAMPDIFF(SECOND, session_start, NOW())
     WHERE id = ? AND user_id = ?'
)->execute([$sessionId, $userId]);

jsonSuccess(['message' => 'Session ended.']);
