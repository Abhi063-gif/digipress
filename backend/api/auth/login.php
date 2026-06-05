<?php
/**
 * POST /api/auth/login.php
 * Body: { email, password }
 * Returns: { status, token, user: { id, name, email, role } }
 *
 * The role field is ALWAYS sourced from the database — never trusted from client.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$body     = getJsonBody();
$email    = strtolower(trim($body['email']    ?? ''));
$password = $body['password'] ?? '';

if (!$email || !$password) jsonError('Email and password are required.');

$db   = getDB();
$stmt = $db->prepare('SELECT id, name, email, password_hash, role, email_verified FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user || !password_verify($password, $user['password_hash'])) {
    jsonError('Invalid email or password.', 401);
}

if (!(bool) $user['email_verified']) {
    jsonError('Please verify your email before logging in.', 403);
}

// ── Re-enforce role from DB (check against ADMIN_EMAILS) ────────────────
$isAdminEmail = in_array(strtolower($email), array_map('strtolower', ADMIN_EMAILS));
$correctRole  = $isAdminEmail ? 'admin' : 'user';

if ($user['role'] !== $correctRole) {
    $db->prepare('UPDATE users SET role = ? WHERE id = ?')
       ->execute([$correctRole, $user['id']]);
    $user['role'] = $correctRole;
}

// Update FCM token if provided
if (!empty($body['fcm_token'])) {
    $db->prepare('UPDATE users SET fcm_token = ? WHERE id = ?')
       ->execute([$body['fcm_token'], $user['id']]);
}

$token = generateToken((int) $user['id'], $user['role']);

jsonSuccess([
    'token' => $token,
    'user'  => [
        'id'    => (int) $user['id'],
        'name'  => $user['name'],
        'email' => $user['email'],
        'role'  => $user['role'],    // 'admin' | 'user'
    ],
]);
