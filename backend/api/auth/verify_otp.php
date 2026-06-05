<?php
/**
 * POST /api/auth/verify_otp.php
 * Body: { email, otp }
 * Marks the user's email as verified.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$body  = getJsonBody();
$email = strtolower(trim($body['email'] ?? ''));
$otp   = trim($body['otp'] ?? '');

$purpose = trim($body['purpose'] ?? '');

if (!$email || !$otp) jsonError('Email and OTP are required.');

$db   = getDB();
$stmt = $db->prepare(
    'SELECT id, otp_code, otp_expires_at FROM users WHERE email = ?'
);
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user)                              jsonError('User not found.', 404);
if ($user['otp_code'] !== $otp)          jsonError('Invalid OTP.');
if (strtotime($user['otp_expires_at']) < time()) jsonError('OTP has expired. Please request a new one.');

// If it's just verifying for a password reset, don't clear the OTP yet. 
// reset_password.php will clear it when the password is actually changed.
if ($purpose === 'reset') {
    jsonSuccess(['message' => 'OTP verified. Proceed to reset password.']);
} else {
    $db->prepare(
        'UPDATE users SET email_verified = 1, otp_code = NULL, otp_expires_at = NULL WHERE id = ?'
    )->execute([$user['id']]);

    jsonSuccess(['message' => 'Email verified successfully. You can now log in.']);
}
