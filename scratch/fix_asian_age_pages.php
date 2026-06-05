<?php
require_once 'c:/wamp64/www/clg_magzine/config/database.php';

try {
    $dsn = 'mysql:host=127.0.0.1;dbname=digipress;charset=utf8mb4';
    $db = new PDO($dsn, 'root', '', [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    // Find the publication
    $stmt = $db->prepare("SELECT id, title, pages FROM publications WHERE title LIKE '%Asian Age Newspaper%'");
    $stmt->execute();
    $pubs = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($pubs)) {
        echo "Could not find any publication with 'Asian Age Newspaper' in the title.\n";
    } else {
        foreach ($pubs as $pub) {
            echo "Found: ID {$pub['id']} - Title: {$pub['title']} - Current Pages: {$pub['pages']}\n";
            
            // Update to 1 page
            $update = $db->prepare("UPDATE publications SET pages = 1 WHERE id = ?");
            if ($update->execute([$pub['id']])) {
                echo "Successfully updated to 1 page.\n";
            } else {
                echo "Failed to update ID {$pub['id']}.\n";
            }
        }
    }
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
