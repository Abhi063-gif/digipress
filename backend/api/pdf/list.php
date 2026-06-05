<?php
/**
 * GET /api/pdf/list.php[?category_id=X&page=1&limit=20]
 * Public endpoint — no auth required.
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonError('Method not allowed.', 405);

$db         = getDB();
$categoryId = isset($_GET['category_id']) ? (int) $_GET['category_id'] : null;
$page       = max(1, (int) ($_GET['page']  ?? 1));
$limit      = min(50,  (int) ($_GET['limit'] ?? 20));
$offset     = ($page - 1) * $limit;

$where  = $categoryId ? 'WHERE p.category_id = ?' : '';
$params = $categoryId ? [$categoryId] : [];

$countSql  = "SELECT COUNT(*) FROM publications p $where";
$countStmt = $db->prepare($countSql);
$countStmt->execute($params);
$totalRows = (int) $countStmt->fetchColumn();

$sql = "SELECT p.id, p.title, p.description, p.pdf_url, p.cover_url, p.pages, p.created_at,
               c.id AS category_id, c.name AS category,
               u.name AS uploaded_by
        FROM publications p
        JOIN categories c ON c.id = p.category_id
        JOIN users      u ON u.id = p.uploaded_by
        $where
        ORDER BY p.created_at DESC
        LIMIT $limit OFFSET $offset";

$stmt = $db->prepare($sql);
$stmt->execute($params);
$publications = $stmt->fetchAll();

jsonSuccess([
    'publications' => $publications,
    'pagination'   => [
        'total'       => (int) $totalRows,
        'page'        => $page,
        'limit'       => $limit,
        'total_pages' => (int) ceil($totalRows / $limit),
    ],
]);
