<?php
/**
 * GET /api/pdf/get.php?id=<id>
 * Header: Optional Authorization: Bearer <token>
 * Returns details for a single publication.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonError('Method not allowed.', 405);

$id = $_GET['id'] ?? null;
if (!$id) jsonError('ID is required.', 400);

$db = getDB();

$sql = "SELECT p.id, p.title, p.description, p.pdf_url, p.cover_url, p.pages, p.created_at, 
               u.name as uploaded_by, c.name as category, p.category_id 
        FROM publications p 
        LEFT JOIN users u ON p.uploaded_by = u.id 
        LEFT JOIN categories c ON p.category_id = c.id 
        WHERE p.id = ?";
$stmt = $db->prepare($sql);
$stmt->execute([$id]);
$pub = $stmt->fetch();

if (!$pub) {
    jsonError('Publication not found.', 404);
}

// Convert numbers and booleans
$pub['id'] = (int)$pub['id'];
$pub['category_id'] = (int)$pub['category_id'];
$pub['pages'] = (int)$pub['pages'];

jsonSuccess([
    'publication' => $pub
]);
