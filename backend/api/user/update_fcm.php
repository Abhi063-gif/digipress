<?php
/**
 * POST /api/user/update_fcm.php
 * Header: Authorization: Bearer <token>
 * Body: { "fcm_token": "<device_fcm_token>" }
 * Saves the device FCM token so push notifications can be sent.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$auth     = requireAuth();
$userId   = $auth['sub'];
$body     = getJsonBody();
$fcmToken = trim($body['fcm_token'] ?? '');

if (empty($fcmToken)) jsonError('fcm_token is required.');

$db = getDB();
$db->prepare('UPDATE users SET fcm_token = ? WHERE id = ?')
   ->execute([$fcmToken, $userId]);

jsonSuccess(['message' => 'FCM token updated.']);
