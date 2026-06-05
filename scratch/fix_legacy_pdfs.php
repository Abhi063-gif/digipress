<?php
require 'c:/wamp64/www/clg_magzine/config/database.php';
require 'c:/wamp64/www/clg_magzine/config/cloudinary.php';

$db = getDB();
$stmt = $db->query("SELECT id, cloudinary_id, pdf_url FROM publications WHERE pdf_url LIKE '%.tmp'");
$pubs = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Found " . count($pubs) . " publications to fix.\n";

foreach ($pubs as $p) {
    $oldId = $p['cloudinary_id'];
    $newId = preg_replace('/\.tmp$/', '.pdf', $oldId);
    if ($oldId === $newId) {
        // If the ID didn't have .tmp but the URL did, let's just append .pdf to the ID
        $newId = $oldId . ".pdf";
    }

    echo "Renaming {$oldId} to {$newId}...\n";

    // Cloudinary Rename API
    $timestamp = time();
    $params = [
        'from_public_id' => $oldId,
        'to_public_id'   => $newId,
        'timestamp'      => $timestamp,
    ];
    ksort($params);
    $signString = "";
    foreach ($params as $k => $v) $signString .= "$k=$v&";
    $signature = sha1(rtrim($signString, '&') . CLOUDINARY_API_SECRET);

    $postFields = [
        'from_public_id' => $oldId,
        'to_public_id'   => $newId,
        'api_key'        => CLOUDINARY_API_KEY,
        'timestamp'      => $timestamp,
        'signature'      => $signature,
    ];

    $url = "https://api.cloudinary.com/v1_1/" . CLOUDINARY_CLOUD_NAME . "/raw/rename";
    
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $postFields,
        CURLOPT_SSL_VERIFYPEER => false,
    ]);
    $resp = json_decode(curl_exec($ch), true);
    curl_close($ch);

    if (isset($resp['secure_url'])) {
        echo "Successfully renamed! New URL: {$resp['secure_url']}\n";
        $update = $db->prepare("UPDATE publications SET pdf_url = ?, cloudinary_id = ? WHERE id = ?");
        $update->execute([$resp['secure_url'], $resp['public_id'], $p['id']]);
    } else {
        echo "Failed to rename: " . ($resp['error']['message'] ?? 'Unknown error') . "\n";
    }
}

echo "Done.\n";
