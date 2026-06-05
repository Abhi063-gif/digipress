<?php
// helpers.php is always included AFTER database.php, so we guard against re-include
if (!function_exists('jsonSuccess')) {

// ── JSON response helpers ─────────────────────────────────────────────────────
function jsonSuccess(array $data = [], int $code = 200): void {
    http_response_code($code);
    echo json_encode(array_merge(['status' => 'success'], $data));
    exit;
}

function jsonError(string $message, int $code = 400): void {
    http_response_code($code);
    echo json_encode(['status' => 'error', 'message' => $message]);
    exit;
}

// ── Input helpers ─────────────────────────────────────────────────────────────
function getJsonBody(): array {
    $raw = file_get_contents('php://input');
    return json_decode($raw, true) ?? [];
}

// ── JWT-like session token (simple HMAC-based) ────────────────────────────────
define('TOKEN_SECRET', 'digipress_S3cr3t_K3y_2024!');  // change in production
define('TOKEN_EXPIRY',  3600 * 24 * 7);               // 7 days

function generateToken(int $userId, string $role): string {
    $header  = base64_encode(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $payload = base64_encode(json_encode([
        'sub'  => $userId,
        'role' => $role,
        'exp'  => time() + TOKEN_EXPIRY,
        'iat'  => time(),
    ]));
    $signature = base64_encode(hash_hmac('sha256', "$header.$payload", TOKEN_SECRET, true));
    return "$header.$payload.$signature";
}

function verifyToken(string $token): ?array {
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;

    [$header, $payload, $sig] = $parts;
    $expectedSig = base64_encode(hash_hmac('sha256', "$header.$payload", TOKEN_SECRET, true));

    if (!hash_equals($expectedSig, $sig)) return null;

    $data = json_decode(base64_decode($payload), true);
    if (!$data || $data['exp'] < time()) return null;

    return $data;
}

// ── Auth middleware ───────────────────────────────────────────────────────────
/**
 * Extracts and validates the Bearer token from the Authorization header.
 * Returns the decoded token payload or exits with 401.
 */
function requireAuth(): array {
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (empty($authHeader) && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }
    if (!str_starts_with($authHeader, 'Bearer ')) {
        jsonError('Unauthorized: no token provided.', 401);
    }
    $token   = substr($authHeader, 7);
    $payload = verifyToken($token);
    if (!$payload) {
        jsonError('Unauthorized: invalid or expired token.', 401);
    }
    return $payload;
}

/**
 * Same as requireAuth() but additionally enforces the admin role.
 * CRITICAL: backend-enforced — frontend cannot bypass this.
 */
function requireAdmin(): array {
    $payload = requireAuth();
    if (($payload['role'] ?? '') !== 'admin') {
        jsonError('Forbidden: admin access required.', 403);
    }
    return $payload;
}

// ── OTP helpers ───────────────────────────────────────────────────────────────
function generateOtp(): string {
    return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
}

/**
 * Sends an OTP email via Gmail SMTP.
 * OTP is also logged to otp_log.txt for development visibility.
 */
function sendOtpEmail(string $toEmail, string $otp, string $purpose = 'verification'): bool {
    // ── Always log OTP for dev visibility ────────────────────────────────────
    $logFile = __DIR__ . '/../otp_log.txt';
    $logLine = '[' . date('Y-m-d H:i:s') . '] '
             . strtoupper($purpose) . ' OTP for ' . $toEmail
             . ' => ' . $otp . PHP_EOL;
    file_put_contents($logFile, $logLine, FILE_APPEND | LOCK_EX);

    // ── Build HTML email ──────────────────────────────────────────────────────
    $purposeLabel = ucfirst($purpose);
    $html = <<<HTML
    <!DOCTYPE html>
    <html>
    <body style="font-family:Arial,sans-serif;background:#f4f4f4;padding:30px;margin:0">
      <div style="max-width:480px;margin:auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08)">
        <div style="background:#1D7FEC;padding:28px 32px">
          <h1 style="color:#fff;margin:0;font-size:22px">📄 DigiPress</h1>
          <p style="color:rgba(255,255,255,0.8);margin:6px 0 0;font-size:13px">College Publications Portal</p>
        </div>
        <div style="padding:32px">
          <p style="color:#333;font-size:15px;margin:0 0 8px">Hello,</p>
          <p style="color:#555;font-size:14px;margin:0 0 24px">
            Here is your <strong>{$purposeLabel}</strong> OTP code for DigiPress:
          </p>
          <div style="background:#f0f6ff;border:2px dashed #1D7FEC;border-radius:10px;padding:20px;text-align:center;margin-bottom:24px">
            <span style="font-size:38px;font-weight:900;letter-spacing:12px;color:#1D7FEC">{$otp}</span>
          </div>
          <p style="color:#888;font-size:13px;margin:0">
            ⏱ This code expires in <strong>10 minutes</strong>.<br>
            Do not share this code with anyone.
          </p>
        </div>
        <div style="background:#f9f9f9;padding:16px 32px;border-top:1px solid #eee">
          <p style="color:#bbb;font-size:11px;margin:0">© 2025 DigiPress · College Publications Portal</p>
        </div>
      </div>
    </body>
    </html>
    HTML;

    // ── Send via Gmail SMTP ───────────────────────────────────────────────────
    try {
        require_once __DIR__ . '/../config/mailer.php';
        smtpSendMail($toEmail, "DigiPress – Your OTP Code", $html);
        return true;
    } catch (RuntimeException $e) {
        // Log the SMTP error but don't break registration flow
        file_put_contents($logFile,
            '[SMTP ERROR] ' . $e->getMessage() . PHP_EOL,
            FILE_APPEND | LOCK_EX
        );
        return false;
    }
}

} // end if (!function_exists('jsonSuccess'))
