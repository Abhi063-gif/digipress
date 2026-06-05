<?php
require 'c:/wamp64/www/clg_magzine/config/database.php';

$db = getDB();
$stmt = $db->query("SELECT id, pdf_url FROM publications WHERE pages IS NULL OR pages <= 0");
$pubs = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Found " . count($pubs) . " publications with missing page count.\n";

foreach ($pubs as $p) {
    echo "Processing #{$p['id']}: {$p['pdf_url']}...\n";
    
    $content = @file_get_contents($p['pdf_url']);
    if (!$content) {
        echo "Failed to fetch PDF content.\n";
        continue;
    }

    $count = 0;
    // More robust regex for PDF page count
    if (preg_match_all("/\/Type\s*\/Page\b/", $content, $matches)) {
        $count = count($matches[0]);
    }

    if ($count > 0) {
        echo "Found {$count} pages. Updating database...\n";
        $upd = $db->prepare("UPDATE publications SET pages = ? WHERE id = ?");
        $upd->execute([$count, $p['id']]);
    } else {
        echo "Could not determine page count. Defaulting to 1.\n";
        $upd = $db->prepare("UPDATE publications SET pages = 1 WHERE id = ?");
        $upd->execute([$p['id']]);
    }
}

echo "Done.\n";
