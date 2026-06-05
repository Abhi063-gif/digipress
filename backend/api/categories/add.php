<?php
/**
 * POST /api/categories/add.php
 * Header: Authorization: Bearer <token>
 * Body: { name }
 *
 * 🔒 ADMIN ONLY — backend enforced via requireAdmin().
 */
require_once __DIR__ . '/../../config/cors.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/helpers.php';

setCorsHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonError('Method not allowed.', 405);

$auth = requireAdmin(); // ← blocks non-admin tokens with 403

$body = getJsonBody();
$name = trim($body['name'] ?? '');
if (!$name) jsonError('Category name is required.');

$db   = getDB();
$stmt = $db->prepare('SELECT id FROM categories WHERE name = ?');
$stmt->execute([$name]);
if ($stmt->fetch()) jsonError('Category already exists.', 409);

$stmt = $db->prepare('INSERT INTO categories (name) VALUES (?)');
$stmt->execute([$name]);

jsonSuccess([
    'message'  => 'Category created.',
    'category' => [
        'id'   => (int) $db->lastInsertId(),
        'name' => $name,
    ],
], 201);
