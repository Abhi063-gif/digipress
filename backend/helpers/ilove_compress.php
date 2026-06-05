<?php
/**
 * iLovePDF Compression Helper
 * ─────────────────────────────────────────────────────────────────────────────
 * Compresses a PDF file using the iLovePDF REST API v2.
 *
 * Workflow:
 *   1. Authenticate  → POST /v1/auth               (get JWT)
 *   2. Start task    → GET  /v1/start/compress      (get server + task_id)
 *   3. Upload file   → POST /v1/upload              (get server_filename)
 *   4. Process       → POST /v1/process             (compress)
 *   5. Download      → GET  /v1/download/{task_id}  (compressed binary)
 *
 * Returns the path to the compressed temporary file on success.
 * Returns the ORIGINAL file path on any failure (graceful degradation —
 * the upload will still succeed, just without compression).
 *
 * Credentials loaded from config/ilove_pdf.php
 */

require_once __DIR__ . '/../config/ilove_pdf.php';

/**
 * Compress a PDF with iLovePDF. Returns path to compressed file (temp),
 * or original path if compression fails.
 *
 * @param  string $filePath  Absolute path to the PDF temp file.
 * @return string            Path to use for Cloudinary upload.
 */
function compressPdfWithIlovePdf(string $filePath): string
{
    $publicKey = ILOVE_PUBLIC_KEY;
    $logFile   = __DIR__ . '/../ilove_compress.log';

    $log = function(string $msg) use ($logFile) {
        $line = '[' . date('Y-m-d H:i:s') . '] ' . $msg . PHP_EOL;
        file_put_contents($logFile, $line, FILE_APPEND | LOCK_EX);
        error_log($msg);
    };

    $log('=== compressPdfWithIlovePdf START === file=' . basename($filePath) . ' size=' . filesize($filePath) . ' bytes');

    try {
        // ── STEP 1: Authenticate ──────────────────────────────────────────────
        $log('Step 1: Authenticating...');
        $authResp = _iloveCurl(
            'POST',
            'https://api.ilovepdf.com/v1/auth',
            [],
            ['Content-Type: application/json'],
            json_encode(['public_key' => $publicKey])
        );

        if (empty($authResp['token'])) {
            $log('Step 1 FAILED: ' . json_encode($authResp));
            return $filePath;
        }
        $jwt = $authResp['token'];
        $log('Step 1 OK. JWT obtained.');

        // ── STEP 2: Start compress task ───────────────────────────────────────
        $log('Step 2: Starting compress task...');
        $startResp = _iloveCurl(
            'GET',
            'https://api.ilovepdf.com/v1/start/compress',
            [],
            [
                'Authorization: Bearer ' . $jwt,
                'Content-Type: application/json',
            ]
        );

        if (empty($startResp['task']) || empty($startResp['server'])) {
            $log('Step 2 FAILED: ' . json_encode($startResp));
            return $filePath;
        }
        $taskId = $startResp['task'];
        $server = $startResp['server'];
        $log("Step 2 OK. server=$server task=$taskId");

        // ── STEP 3: Upload the PDF ────────────────────────────────────────────
        $log('Step 3: Uploading PDF to iLovePDF server...');
        $uploadUrl  = "https://{$server}/v1/upload";
        $uploadResp = _iloveCurl(
            'POST',
            $uploadUrl,
            [],
            ['Authorization: Bearer ' . $jwt],
            null,
            [
                'task' => $taskId,
                // Force filename to .pdf — iLovePDF rejects files without a .pdf extension.
                // PHP temp files are named phpXXXX.tmp which iLovePDF refuses.
                'file' => new CURLFile($filePath, 'application/pdf', 'document.pdf'),
            ]
        );

        if (empty($uploadResp['server_filename'])) {
            $log('Step 3 FAILED: ' . json_encode($uploadResp));
            return $filePath;
        }
        $serverFilename = $uploadResp['server_filename'];
        $log("Step 3 OK. server_filename=$serverFilename");

        // ── STEP 4: Process (compress) ────────────────────────────────────────
        $log('Step 4: Processing (compress)...');
        $processUrl  = "https://{$server}/v1/process";
        $processBody = json_encode([
            'task'              => $taskId,
            'tool'              => 'compress',
            'compression_level' => 'extreme',
            'files'             => [
                [
                    'server_filename' => $serverFilename,
                    'filename'        => basename($filePath),
                ],
            ],
        ]);
        $processResp = _iloveCurl(
            'POST',
            $processUrl,
            [],
            [
                'Authorization: Bearer ' . $jwt,
                'Content-Type: application/json',
            ],
            $processBody
        );

        if (!empty($processResp['error'])) {
            $log('Step 4 FAILED: ' . json_encode($processResp));
            return $filePath;
        }
        $log('Step 4 OK: ' . json_encode($processResp));

        // ── STEP 5: Download compressed file ──────────────────────────────────
        $log('Step 5: Downloading compressed PDF...');
        $downloadUrl      = "https://{$server}/v1/download/{$taskId}";
        $compressedBinary = _iloveCurlDownload(
            $downloadUrl,
            ['Authorization: Bearer ' . $jwt]
        );

        if (empty($compressedBinary)) {
            $log('Step 5 FAILED: Download returned empty. Using original.');
            return $filePath;
        }

        // Save to a temp file
        $tmpCompressed = tempnam(sys_get_temp_dir(), 'ilove_') . '.pdf';
        file_put_contents($tmpCompressed, $compressedBinary);

        $origSize       = filesize($filePath);
        $compressedSize = filesize($tmpCompressed);
        $log(sprintf(
            'Step 5 OK. Original: %d bytes → Compressed: %d bytes (%.1f%% reduction)',
            $origSize,
            $compressedSize,
            ($origSize > 0) ? (1 - $compressedSize / $origSize) * 100 : 0
        ));

        if ($compressedSize >= $origSize) {
            $log('Compressed file is not smaller. Using original.');
            @unlink($tmpCompressed);
            return $filePath;
        }

        $log('=== compressPdfWithIlovePdf SUCCESS ===');
        return $tmpCompressed;

    } catch (Throwable $e) {
        $log('EXCEPTION: ' . $e->getMessage());
        return $filePath;
    }
}


// ─────────────────────────────────────────────────────────────────────────────
//  Internal cURL helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Generic cURL helper — returns decoded JSON array.
 *
 * @param string      $method      'GET' | 'POST'
 * @param string      $url
 * @param array       $queryParams Query string params (GET)
 * @param array       $headers     HTTP headers
 * @param string|null $body        Raw JSON body (for POST with Content-Type: application/json)
 * @param array|null  $multipart   Multipart fields (for file upload POST)
 */
function _iloveCurl(
    string $method,
    string $url,
    array $queryParams = [],
    array $headers = [],
    ?string $body = null,
    ?array $multipart = null
): array {
    if (!empty($queryParams)) {
        $url .= '?' . http_build_query($queryParams);
    }

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        // Spoof origin as production domain — iLovePDF's domain filter checks this header.
        // PHP/cURL never sends Origin automatically, so we set it manually to our allowed domain.
        CURLOPT_HTTPHEADER     => array_merge(['Origin: https://www.mydigipress.in'], $headers),
        CURLOPT_TIMEOUT        => 300,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_FOLLOWLOCATION => true,
    ]);

    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        if ($multipart !== null) {
            // Multipart form-data (file upload)
            curl_setopt($ch, CURLOPT_POSTFIELDS, $multipart);
        } elseif ($body !== null) {
            // Raw JSON body
            curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
        }
    }

    $raw  = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err  = curl_error($ch);
    curl_close($ch);

    if ($err) {
        throw new RuntimeException("iLovePDF cURL error: $err");
    }

    $decoded = json_decode($raw, true);
    if ($decoded === null) {
        // Some endpoints return non-JSON on error
        error_log("[iLovePDF] Non-JSON response (HTTP $code): " . substr($raw, 0, 300));
        return ['_raw' => $raw, '_http_code' => $code];
    }
    return $decoded;
}

/**
 * Downloads binary content from a URL and returns it as a string.
 */
function _iloveCurlDownload(string $url, array $headers = []): string
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => array_merge(['Origin: https://www.mydigipress.in'], $headers),
        CURLOPT_TIMEOUT        => 300,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_FOLLOWLOCATION => true,
    ]);

    $raw = curl_exec($ch);
    $err = curl_error($ch);
    curl_close($ch);

    if ($err) {
        throw new RuntimeException("iLovePDF download cURL error: $err");
    }

    return $raw ?: '';
}
