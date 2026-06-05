<?php
require 'c:/wamp64/www/clg_magzine/config/database.php';
$db = getDB();
$stmt = $db->query('SELECT id, title, pdf_url FROM publications ORDER BY id DESC LIMIT 5');
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo json_encode($rows, JSON_PRETTY_PRINT);
