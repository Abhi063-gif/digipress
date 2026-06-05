<?php
/** GET /api/categories/list.php — public */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonError('Method not allowed.', 405);

$db   = getDB();
$cats = $db->query("SELECT id, name, COALESCE(icon,'📁') AS icon, COALESCE(color,'#6366f1') AS color FROM categories ORDER BY name")->fetchAll();

jsonSuccess(['categories' => $cats]);
