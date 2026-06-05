<?php
/**
 * POST /api/user/sessionStart.php
 * POST /api/user/sessionEnd.php
 * Tracks app session duration for the admin panel "Avg Session Time" stat.
 *
 * sessionStart: Body {} → returns { session_id }
 * sessionEnd:   Body { session_id } → updates duration_sec
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];

$db = getDB();
$db->prepare('INSERT INTO app_sessions (user_id, session_start) VALUES (?, NOW())')
   ->execute([$userId]);

$sessionId = (int)$db->lastInsertId();
jsonSuccess(['session_id' => $sessionId]);
