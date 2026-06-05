<?php
/**
 * POST /api/auth/register.php
 * Body: { name, email, password }
 * Creates user (role assigned by backend based on ADMIN_EMAIL),
 * sends OTP for email verification.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$body     = getJsonBody();
$name     = trim($body['name']     ?? '');
$email    = strtolower(trim($body['email']    ?? ''));
$password = $body['password'] ?? '';

// ── Validate ──────────────────────────────────────────────────────────────────
if (!$name || !$email || !$password)        jsonError('Name, email, and password are required.');
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) jsonError('Invalid email address.');
if (strlen($password) < 8)                 jsonError('Password must be at least 8 characters.');

$db = getDB();

// Check duplicate
$stmt = $db->prepare('SELECT id FROM users WHERE email = ?');
$stmt->execute([$email]);
if ($stmt->fetch()) jsonError('This email is already registered.', 409);

// ── Assign role (BACKEND-ENFORCED) ────────────────────────────────────────────
$isAdminEmail = in_array(strtolower($email), array_map('strtolower', ADMIN_EMAILS));
$role         = $isAdminEmail ? 'admin' : 'user';

$hash = password_hash($password, PASSWORD_BCRYPT);
$otp  = generateOtp();
$exp  = date('Y-m-d H:i:s', time() + 600); // 10 minutes

$stmt = $db->prepare(
    'INSERT INTO users (name, email, password_hash, role, otp_code, otp_expires_at)
     VALUES (?, ?, ?, ?, ?, ?)'
);
$stmt->execute([$name, $email, $hash, $role, $otp, $exp]);
$userId = (int) $db->lastInsertId();

sendOtpEmail($email, $otp, 'email verification');

jsonSuccess([
    'message' => 'Registration successful. Please verify your email with the OTP sent.',
    'user_id' => $userId,
], 201);
