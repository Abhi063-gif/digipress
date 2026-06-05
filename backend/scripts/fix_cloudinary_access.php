<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/cloudinary.php';

$db = getDB();
$stmt = $db->query("SELECT id, title, cloudinary_id, pdf_url FROM publications");
$pubs = $stmt->fetchAll();

echo "Starting fix for " . count($pubs) . " publications...\n";

foreach ($pubs as $pub) {
    $publicId = $pub['cloudinary_id'];
    if (!$publicId) {
        echo "Skipping Pub {$pub['id']} (No Cloudinary ID)\n";
        continue;
    }

    echo "Fixing Pub {$pub['id']}: {$pub['title']} ($publicId)... ";
    
    // Determine resource type (images are images, others are raw)
    $resourceType = (strpos($pub['pdf_url'], '/image/upload/') !== false) ? 'image' : 'raw';
    
    $success = cloudinaryMakePublic($publicId, $resourceType);
    
    if ($success) {
        echo "SUCCESS\n";
    } else {
        echo "FAILED\n";
    }
}

echo "Done.\n";
