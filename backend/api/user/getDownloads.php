<?php
/**
 * GET /api/user/getDownloads.php
 * Header: Authorization: Bearer <token>
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonError('Method not allowed.', 405);

$auth   = requireAuth();
$userId = $auth['sub'];

$db = getDB();
$stmt = $db->prepare('
    SELECT p.id as pdf_id, p.title, p.pdf_url as file_url, p.cover_url, 
           c.name as category, d.downloaded_at as timestamp
    FROM downloads d
    JOIN publications p ON d.pub_id = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE d.user_id = ?
    ORDER BY d.downloaded_at DESC
');
$stmt->execute([$userId]);
$downloads = $stmt->fetchAll();

foreach ($downloads as &$d) {
    $d['pdf_id'] = (int) $d['pdf_id'];
}

jsonSuccess(['downloads' => $downloads]);
