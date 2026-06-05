<?php
/**
 * POST /api/user/update_profile.php
 * Header: Authorization: Bearer <token>
 * Body: { "user_type": "student"|"teacher", "department": "...", "class_name": "...", "roll_number": "..." }
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];
$body   = getJsonBody();

$userType   = isset($body['user_type']) ? strtolower(trim($body['user_type'])) : null;
$department = trim($body['department'] ?? '');
$className  = trim($body['class_name'] ?? '');
$rollNumber = trim($body['roll_number'] ?? '');

if ($userType && !in_array($userType, ['student', 'teacher'])) {
    jsonError('Invalid user_type. Must be student or teacher.', 400);
}

// Clear irrelevant fields based on role
if ($userType === 'teacher') {
    $className = null;
    $rollNumber = null;
} elseif ($userType === 'student') {
    $department = null;
}

$db = getDB();
$stmt = $db->prepare('UPDATE users SET user_type = ?, department = ?, class_name = ?, roll_number = ? WHERE id = ?');
$stmt->execute([$userType, $department, $className, $rollNumber, $userId]);

jsonSuccess(['message' => 'Profile updated successfully.']);
