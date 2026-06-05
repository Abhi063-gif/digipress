<?php
/**
 * POST /api/pdf/delete.php
 * Header: Authorization: Bearer <token>
 * JSON Body: { "id": 123 }
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/cloudinary.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

// Admin check
$auth = requireAdmin();

$body = getJsonBody();
$pubId = (int) ($body['id'] ?? 0);

if (!$pubId) jsonError('Publication ID required.');

$db = getDB();

// 1. Fetch publication to get details
$stmt = $db->prepare('SELECT title, cloudinary_id, pdf_url FROM publications WHERE id = ?');
$stmt->execute([$pubId]);
$pub = $stmt->fetch();

if (!$pub) jsonError('Publication not found.', 404);

$title        = $pub['title'];
$cloudinaryId = $pub['cloudinary_id'];
$pdfUrl       = $pub['pdf_url'];

// Determine resource type for deletion
$resourceType = 'raw';
if (preg_match('/\.(jpg|jpeg|png|webp)$/i', $pdfUrl)) {
    $resourceType = 'image';
}

// 2. Delete from Cloudinary
$cloudSuccess = true;
if ($cloudinaryId) {
    try {
        $cloudSuccess = cloudinaryDelete($cloudinaryId, $resourceType);
    } catch (Exception $e) {
        error_log("[DELETE ERROR] Cloudinary deletion failed for ID $cloudinaryId: " . $e->getMessage());
        $cloudSuccess = false;
    }
}

// 3. Delete from DB (always do this if it existed in DB)
$db->prepare('DELETE FROM publications WHERE id = ?')->execute([$pubId]);

require_once __DIR__ . '/../../helpers/send_notification.php';

if ($cloudSuccess) {
    // 4. Notify users about deletion
    try {
        broadcastNotification(
            'Publication Removed',
            "The document '$title' is no longer available in the library.",
            ['type' => 'deletion', 'id' => $pubId]
        );
    } catch (Exception $e) {
        error_log("[NOTIFY ERROR] Deletion broadcast failed: " . $e->getMessage());
    }

    jsonSuccess(['message' => 'Publication deleted successfully from database and Cloudinary.']);
} else {
    jsonSuccess([
        'message' => 'Publication removed from database, but Cloudinary deletion failed or was not needed.',
        'warning' => 'Manual cleanup of Cloudinary asset may be required.'
    ]);
}
