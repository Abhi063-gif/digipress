<?php
/**
 * STANDALONE CLOUDINARY DEBUG SCRIPT
 */
require_once __DIR__ . '/config/cloudinary.php';

function debugLog($msg) {
    echo "[" . date('H:i:s') . "] $msg\n";
}

debugLog("DEBUG: Starting standalone Cloudinary test...");
debugLog("DEBUG: Cloud Name: " . CLOUDINARY_CLOUD_NAME);

// Create a valid-ish PDF
$pdf = "%PDF-1.1\n" .
       "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n" .
       "2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n" .
       "3 0 obj << /Type /Page /Parent 2 0 R /Contents 4 0 R /MediaBox [0 0 612 792] >> endobj\n" .
       "4 0 obj << /Length 51 >> stream\n" .
       "BT /F1 12 Tf 72 720 Td (Hello World) Tj ET\n" .
       "endstream endobj\n" .
       "xref\n0 5\n0000000000 65535 f\n0000000018 00000 n\n0000000077 00000 n\n0000000133 00000 n\n0000000244 00000 n\n" .
       "trailer << /Size 5 /Root 1 0 R >>\n" .
       "startxref\n345\n%%EOF";

$testFile = __DIR__ . '/test_debug.pdf';
file_put_contents($testFile, $pdf);

function testUrl($url, $label) {
    debugLog("DEBUG: Testing $label accessibility...");
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_NOBODY         => true,
        CURLOPT_HEADER         => true,
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_FOLLOWLOCATION => true,
    ]);
    $headers = curl_exec($ch);
    $info = curl_getinfo($ch);
    curl_close($ch);
    
    debugLog("DEBUG: $label Response Code: " . $info['http_code']);
    if ($info['http_code'] == 200) {
        debugLog("DEBUG: ✅ $label is SUCCESSFUL!");
        return true;
    } else {
        debugLog("DEBUG: ❌ $label FAILED with $info[http_code]");
        if (preg_match('/x-cld-error: (.*)/i', $headers, $m)) {
            debugLog("DEBUG: Cloudinary Error: " . trim($m[1]));
        }
        return false;
    }
}

try {
    debugLog("DEBUG: Uploading PDF as RAW...");
    $resultRaw = cloudinaryUpload($testFile, 'debug_tests', 'raw', 10*1024*1024, 'application/pdf', 'upload');
    $rawOk = testUrl($resultRaw['secure_url'], "RAW PDF URL");

    debugLog("\nDEBUG: --- Testing SIGNED URL for the restricted RAW asset ---");
    $timestamp = time();
    $publicId = $resultRaw['public_id'];
    $version = $resultRaw['version'];
    
    // To deliver a signed URL, we usually need the signature at the END or via params
    // For RAW assets, it's usually via a 'token' or 'signature' param if 'Secure Delivery' is on.
    
    // Actually, Cloudinary's 'Secure Delivery' usually means we need to use a 's--<sig>--' prefix
    // OR a signature parameter.
    
    // Let's try to generate a signature for the delivery URL
    $toSign = "public_id=$publicId&timestamp=$timestamp" . CLOUDINARY_API_SECRET;
    $deliverySig = sha1($toSign);
    
    $signedUrl = $resultRaw['secure_url'] . "?timestamp=$timestamp&signature=$deliverySig&api_key=" . CLOUDINARY_API_KEY;
    debugLog("DEBUG: Testing SIGNED RAW URL: $signedUrl");
    
    testUrl($signedUrl, "SIGNED RAW URL");

    cloudinaryDelete($resultRaw['public_id'], 'raw');

    debugLog("\nDEBUG: Uploading PDF as IMAGE...");
    $resultImg = cloudinaryUpload($testFile, 'debug_tests', 'image', 10*1024*1024, 'application/pdf', 'upload');
    $imgOk = testUrl($resultImg['secure_url'], "IMAGE PDF URL");
    cloudinaryDelete($resultImg['public_id'], 'image');

    if (!$rawOk && $imgOk) {
        debugLog("\nDEBUG: 💡 CONCLUSION: 'Raw' assets are blocked by account settings. 'Image' assets are public.");
        debugLog("DEBUG: SOLUTION: Change PDFs to upload as 'image' resource type OR disable 'Raw' restriction in Cloudinary Security settings.");
    } elseif (!$rawOk && !$imgOk) {
        debugLog("\nDEBUG: 💡 CONCLUSION: Both RAW and IMAGE are blocked. 'Secure Delivery' is likely enabled for the entire account.");
    }

} catch (Exception $e) {
    debugLog("DEBUG: CRITICAL ERROR: " . $e->getMessage());
}

if (file_exists($testFile)) unlink($testFile);
debugLog("DEBUG: Test finished.");
