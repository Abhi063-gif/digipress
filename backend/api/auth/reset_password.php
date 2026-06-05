<?php
/**
 * POST /api/auth/reset_password.php
 * Body: { email, otp, new_password }
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$body         = getJsonBody();
$email        = strtolower(trim($body['email']        ?? ''));
$otp          = trim($body['otp']          ?? '');
$newPassword  = $body['new_password'] ?? '';

if (!$email || !$otp || !$newPassword) jsonError('Email, OTP, and new password are required.');
if (strlen($newPassword) < 8) jsonError('Password must be at least 8 characters.');

$db   = getDB();
$stmt = $db->prepare('SELECT id, otp_code, otp_expires_at FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user)                              jsonError('User not found.', 404);

if ($user['otp_code'] !== $otp) {
    // Log mismatch for debugging
    $logFile = __DIR__ . '/../../otp_log.txt';
    $logLine = '[' . date('Y-m-d H:i:s') . '] RESET MISMATCH for ' . $email 
             . ' => Expected: ' . ($user['otp_code'] ?? 'NULL') 
             . ', Received: ' . $otp . PHP_EOL;
    file_put_contents($logFile, $logLine, FILE_APPEND | LOCK_EX);
    
    jsonError('Invalid OTP.');
}

if (strtotime($user['otp_expires_at']) < time()) jsonError('OTP has expired.');

$hash = password_hash($newPassword, PASSWORD_BCRYPT);
$db->prepare(
    'UPDATE users SET password_hash = ?, otp_code = NULL, otp_expires_at = NULL WHERE id = ?'
)->execute([$hash, $user['id']]);

jsonSuccess(['message' => 'Password reset successfully. Please log in with your new password.']);
