<?php
/**
 * POST /api/pdf/upload.php
 * Header: Authorization: Bearer <token>
 * Form data (multipart): title, description, category_id, pdf_file
 *
 * 🔒 ADMIN ONLY — backend strictly enforces this.
 *    Returns 403 if the token belongs to a non-admin user.
 */

// ── CRITICAL: SET LIMITS BEFORE ANY PROCESSING ───────────────────────────────
set_time_limit(600); // 10 minutes for large files
ini_set('memory_limit', '512M');
ini_set('upload_max_filesize', '60M'); // Increased to match .htaccess
ini_set('post_max_size', '70M');      // Increased to match .htaccess
ini_set('display_errors', 0);
error_reporting(E_ALL);

require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/cloudinary.php';
require_once __DIR__ . '/../../helpers/helpers.php';
require_once __DIR__ . '/../../helpers/send_notification.php';
require_once __DIR__ . '/../../helpers/ilove_compress.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

// ── Check for Post Max Size Violation ────────────────────────────────────────
// If the request body exceeds post_max_size, $_POST and $_FILES will be empty.
if (empty($_POST) && empty($_FILES) && $_SERVER['CONTENT_LENGTH'] > 0) {
    jsonError('The file is too large for the server to process. Please compress it below 10MB.', 413);
}

// ── MUST be admin (backend check) ─────────────────────────────────────────────
$auth = requireAdmin();

$title       = trim($_POST['title']       ?? '');
$description = trim($_POST['description'] ?? '');
$categoryId  = (int) ($_POST['category_id'] ?? 0);

if (!$title)      jsonError('Publication title is required.');
if (!$categoryId) jsonError('Category is required.');

// ── Validate uploaded file ─────────────────────────────────────────────────────
if (!isset($_FILES['pdf_file']) || $_FILES['pdf_file']['error'] !== UPLOAD_ERR_OK) {
    $err = $_FILES['pdf_file']['error'] ?? 'Missing';
    $msg = 'File is required.';
    if ($err === UPLOAD_ERR_INI_SIZE || $err === UPLOAD_ERR_FORM_SIZE) {
        $msg = 'File is too large. Max server limit is 60MB, but we recommend staying under 10MB.';
    } elseif ($err === UPLOAD_ERR_PARTIAL) {
        $msg = 'File upload was interrupted.';
    } elseif ($err === 'Missing') {
        $msg = 'No file was received. Ensure the field name is "pdf_file".';
    }
    error_log("[UPLOAD ERROR] Error code: $err");
    jsonError($msg);
}

$file     = $_FILES['pdf_file'];
$mimeType = mime_content_type($file['tmp_name']);
$db       = getDB();

// Fetch category info
$catStmt = $db->prepare('SELECT name FROM categories WHERE id = ?');
$catStmt->execute([$categoryId]);
$category = $catStmt->fetch();
if (!$category) jsonError('Invalid category.', 422);
$catName = $category['name'];

$allowedMimeTypes = ['application/pdf', 'application/x-pdf'];
// If category is "Notice", also allow images
if (strtolower($catName) === 'notice') {
    $allowedMimeTypes = array_merge($allowedMimeTypes, ['image/jpeg', 'image/png', 'image/webp', 'image/jpg']);
}

if (!in_array($mimeType, $allowedMimeTypes)) {
    $errorMsg = strtolower($catName) === 'notice'
        ? 'Only PDF or Image (JPG, PNG, WebP) files are allowed for Notices.'
        : 'Only PDF files are allowed for this category.';
    jsonError($errorMsg);
}

$maxSize = 25 * 1024 * 1024; // 25 MB PHP-level limit (allow headroom for processing)
if ($file['size'] > $maxSize) jsonError('File size must not exceed 25 MB before server processing.');

// Determine Cloudinary resource type
$resourceType = (str_starts_with($mimeType, 'image/')) ? 'image' : 'raw';

// ── Validate temp file exists ──────────────────────────────────────────────────
$absolutePath = realpath($file['tmp_name']);
if (!$absolutePath || !file_exists($absolutePath)) {
    jsonError('Temporary file not found on server.');
}

// ── iLovePDF Compression (PDFs > 10 MB only) ──────────────────────────────────
$uploadPath         = $absolutePath;
$compressedTempPath = null; // track temp file for cleanup

if ($mimeType === 'application/pdf' && $file['size'] > 10 * 1024 * 1024) {
    $origMB = round($file['size'] / 1048576, 1);
    error_log("[UPLOAD] PDF is {$origMB} MB (>10 MB). Attempting iLovePDF compression...");

    $compressed = compressPdfWithIlovePdf($absolutePath);

    if ($compressed !== $absolutePath) {
        $uploadPath         = $compressed;
        $compressedTempPath = $compressed;
        $compressedMB = round(filesize($compressed) / 1048576, 1);
        error_log("[UPLOAD] Compression OK: {$origMB} MB → {$compressedMB} MB");
    } else {
        error_log("[UPLOAD] Compression skipped/failed. Uploading original {$origMB} MB.");
    }
}

// ── Post-compression 10 MB guard (Cloudinary Hard Limit) ────────────────────────
$finalSizeBytes = filesize($uploadPath);
if ($finalSizeBytes > 10 * 1024 * 1024) {
    if ($compressedTempPath && file_exists($compressedTempPath)) @unlink($compressedTempPath);
    $finalMB = round($finalSizeBytes / 1048576, 1);
    jsonError(
        "PDF upload limit is 10MB. Please try to compress the file.",
        422
    );
}

// ── Upload to Cloudinary ───────────────────────────────────────────────────────
error_log("[UPLOAD] Starting Cloudinary upload for: " . $title);
$startTime = microtime(true);
try {
    $limiter   = 6 * 1024 * 1024; // 6 MB chunk size
    $cloudResp = cloudinaryUpload($uploadPath, 'digipress/publications', $resourceType, $limiter, $mimeType, 'upload');
    $duration  = round(microtime(true) - $startTime, 2);
    error_log("[UPLOAD] Cloudinary finished in {$duration}s");
} catch (RuntimeException $e) {
    if ($compressedTempPath && file_exists($compressedTempPath)) @unlink($compressedTempPath);
    error_log("[UPLOAD] Cloudinary FAILED: " . $e->getMessage());
    jsonError('Upload failed: ' . $e->getMessage(), 422);
} finally {
    if ($compressedTempPath && file_exists($compressedTempPath)) @unlink($compressedTempPath);
}

$pdfUrl       = $cloudResp['secure_url'];
$cloudinaryId = $cloudResp['public_id'];

// ── Verify URL accessibility ──────────────────────────────────────────────────
$ch = curl_init($pdfUrl);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_NOBODY         => true, // HEAD request
    CURLOPT_TIMEOUT        => 10,
    CURLOPT_SSL_VERIFYPEER => false,
]);
curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 200) {
    // If not public, delete from Cloudinary and fail
    cloudinaryDelete($cloudinaryId, $resourceType);
    error_log("[UPLOAD ERROR] URL not public ($httpCode): $pdfUrl");
    jsonError("The uploaded PDF is not publicly accessible (HTTP $httpCode). Please check your Cloudinary Security settings (Strict transformations/Secure delivery).", 422);
}

// ── Extract Pages ────────────────────────────────────────────────────────────
$pagesCount = 1;
$pagesOverride = isset($_POST['pages_override']) ? (int)$_POST['pages_override'] : 0;

if ($pagesOverride > 0) {
    $pagesCount = $pagesOverride;
} elseif ($mimeType === 'application/pdf') {
    try {
        $pdfContent = @file_get_contents($uploadPath);
        if ($pdfContent) {
            // 1. Try to find /Count in the Pages dictionary
            if (preg_match("/\/Type\s*\/Pages.*?\/Count\s+(\d+)/s", $pdfContent, $m)) {
                $pagesCount = (int)$m[1];
            } 
            // 2. Fallback: Count /Type /Page that have a /MediaBox (mandatory for real pages)
            elseif (preg_match_all("/\/Type\s*\/Page\b[^>]*?\/MediaBox/s", $pdfContent, $matches)) {
                $pagesCount = count($matches[0]);
            }
            // 3. Last resort fallback
            elseif (preg_match_all("/\/Type\s*\/Page\b/", $pdfContent, $matches)) {
                $pagesCount = count($matches[0]);
            }
        }
    } catch (Exception $e) {}
}
if ($pagesCount <= 0) $pagesCount = 1;

// ── Save to DB ─────────────────────────────────────────────────────────────────
$stmt = $db->prepare(
    'INSERT INTO publications (title, description, category_id, pdf_url, cloudinary_id, uploaded_by, pages)
     VALUES (?, ?, ?, ?, ?, ?, ?)'
);
$stmt->execute([$title, $description, $categoryId, $pdfUrl, $cloudinaryId, $auth['sub'], $pagesCount]);
$pubId = (int) $db->lastInsertId();

// ── Broadcast notification ─────────────────────────────────────────────────────
try {
    broadcastNotification(
        "🚀 New Upload: $title",
        "A new publication has been added to the $catName category. Tap to view the document.",
        ['type' => 'upload', 'pub_id' => $pubId, 'category' => $catName]
    );
} catch (Exception $e) {
    error_log("[NOTIFY ERROR] Upload broadcast failed: " . $e->getMessage());
}

jsonSuccess([
    'message'     => 'Publication uploaded successfully.',
    'publication' => [
        'id'      => $pubId,
        'title'   => $title,
        'pdf_url' => $pdfUrl,
    ],
], 201);
