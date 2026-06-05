<?php
/**
 * GET /api/user/profile.php
 * Header: Authorization: Bearer <token>
 * Returns the current user's profile (name, email, role).
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];

$db   = getDB();
$stmt = $db->prepare('SELECT id, name, email, role, user_type, department, class_name, roll_number, created_at FROM users WHERE id = ?');
$stmt->execute([$userId]);
$user = $stmt->fetch();

if (!$user) jsonError('User not found.', 404);

jsonSuccess([
    'user' => [
        'id'          => (int) $user['id'],
        'name'        => $user['name'],
        'email'       => $user['email'],
        'role'        => $user['role'],
        'user_type'   => $user['user_type'],
        'department'  => $user['department'],
        'class_name'  => $user['class_name'],
        'roll_number' => $user['roll_number'],
        'created_at'  => $user['created_at'],
    ],
]);
