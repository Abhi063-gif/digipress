<?php
require_once 'c:/wamp64/www/clg_magzine/config/database.php';
$db = getDB();

function getPdfPages($url) {
    if (!$url) return 0;
    try {
        $content = file_get_contents($url);
        if (!$content) return 0;
        if (preg_match_all("/\/Type\s*\/Page[^s]/", $content, $matches)) {
            return count($matches[0]);
        }
    } catch (Exception $e) {}
    return 0;
}

try {
    // Reset the dummy data
    $db->exec("UPDATE publications SET download_count = 0, view_count = 0, share_count = 0");
    
    // Attempt to update pages for existing publications
    $stmt = $db->query("SELECT id, pdf_url FROM publications WHERE pages = 0");
    $pubs = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($pubs as $p) {
        $pages = getPdfPages($p['pdf_url']);
        if ($pages > 0) {
            $db->prepare("UPDATE publications SET pages = ? WHERE id = ?")->execute([$pages, $p['id']]);
        }
    }
    echo "Reset complete and pages calculated.\n";
} catch(PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
