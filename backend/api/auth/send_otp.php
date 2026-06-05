<?php
/**
 * POST /api/auth/send_otp.php
 * Body: { email }
 * Sends a fresh OTP for password reset.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$body  = getJsonBody();
$email = strtolower(trim($body['email'] ?? ''));
if (!$email) jsonError('Email is required.');

$db   = getDB();
$stmt = $db->prepare('SELECT id FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch();

// Always respond vaguely (prevent user enumeration)
if (!$user) {
    jsonSuccess(['message' => 'If this email is registered, an OTP has been sent.']);
}

$otp = generateOtp();
$exp = date('Y-m-d H:i:s', time() + 600);

$db->prepare('UPDATE users SET otp_code = ?, otp_expires_at = ? WHERE id = ?')
   ->execute([$otp, $exp, $user['id']]);

sendOtpEmail($email, $otp, 'password reset');

jsonSuccess(['message' => 'If this email is registered, an OTP has been sent.']);
