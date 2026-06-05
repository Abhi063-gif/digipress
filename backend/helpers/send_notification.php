<?php
/**
 * Firebase Cloud Messaging (FCM) — HTTP v1 API
 * Uses the Service Account JSON to get an OAuth2 access token,
 * then broadcasts a notification to every registered device token.
 */

define('FCM_CREDENTIALS_PATH', __DIR__ . '/../config/digipress-c6d14-firebase-adminsdk-fbsvc-9a1a46e43c.json');
define('FCM_PROJECT_ID', 'digipress-c6d14');
define('FCM_SCOPE', 'https://www.googleapis.com/auth/firebase.messaging');

/**
 * Generate an OAuth2 access token from the Service Account JSON.
 */
function getFcmAccessToken(): ?string {
    if (!file_exists(FCM_CREDENTIALS_PATH)) return null;

    $creds = json_decode(file_get_contents(FCM_CREDENTIALS_PATH), true);
    if (!$creds || empty($creds['private_key']) || empty($creds['client_email'])) return null;

    // Build JWT
    $header  = base64_url_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $now     = time();
    $payload = base64_url_encode(json_encode([
        'iss'   => $creds['client_email'],
        'scope' => FCM_SCOPE,
        'aud'   => 'https://oauth2.googleapis.com/token',
        'iat'   => $now,
        'exp'   => $now + 3600,
    ]));

    $sigInput = "$header.$payload";
    $sig = '';
    openssl_sign($sigInput, $sig, $creds['private_key'], 'SHA256');
    $jwt = "$sigInput." . base64_url_encode($sig);

    // Exchange JWT for access token
    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ]),
        CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
    ]);
    $resp = curl_exec($ch);
    curl_close($ch);

    $data = json_decode($resp, true);
    return $data['access_token'] ?? null;
}

function base64_url_encode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/**
 * Send FCM push notification to a single device token.
 */
function sendFcmToToken(string $accessToken, string $deviceToken, string $title, string $body, array $data = []): bool {
    $payload = [
        'message' => [
            'token'        => $deviceToken,
            'notification' => [
                'title' => $title,
                'body'  => $body,
                'image' => $data['image_url'] ?? null,
            ],
            'android'      => [
                'priority' => 'high',
                'notification' => [
                    'channel_id' => 'digipress_updates',
                    'sound'      => 'default',
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                ],
            ],
            'data'         => array_merge(['click_action' => 'FLUTTER_NOTIFICATION_CLICK'], array_map('strval', $data)),
        ],
    ];

    $ch = curl_init('https://fcm.googleapis.com/v1/projects/' . FCM_PROJECT_ID . '/messages:send');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => json_encode($payload),
        CURLOPT_HTTPHEADER     => [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json',
        ],
    ]);
    $resp   = curl_exec($ch);
    $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return $status === 200;
}

/**
 * Broadcast notification to ALL users who have a stored FCM token,
 * AND save the notification to the database for historical viewing.
 */
function broadcastNotification(string $title, string $body, array $data = []): void {
    $db = getDB();

    // 1. Save to database first
    try {
        $stmt = $db->prepare(
            'INSERT INTO notifications (title, body, category, pub_id) VALUES (?, ?, ?, ?)'
        );
        $stmt->execute([
            $title,
            $body,
            $data['category'] ?? null,
            $data['pub_id']   ?? null
        ]);
    } catch (PDOException $e) {
        error_log("[NOTIFY DB ERROR] " . $e->getMessage());
    }

    // 2. Trigger FCM push
    $accessToken = getFcmAccessToken();
    if (!$accessToken) {
        error_log("[FCM ERROR] Failed to get access token");
        return;
    }

    $stmt  = $db->query('SELECT fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != \'\'');
    $tokens = $stmt->fetchAll(PDO::FETCH_COLUMN);

    if (empty($tokens)) {
        error_log("[FCM INFO] No device tokens found to broadcast.");
        return;
    }

    error_log("[FCM] Broadcasting to " . count($tokens) . " devices...");
    foreach ($tokens as $token) {
        sendFcmToToken($accessToken, $token, $title, $body, $data);
    }
}
