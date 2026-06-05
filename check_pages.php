<?php
require_once 'c:/wamp64/www/clg_magzine/config/database.php';
$db = getDB();
print_r($db->query('SELECT id, title, pages FROM publications')->fetchAll(PDO::FETCH_ASSOC));
