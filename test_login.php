<?php
$data = json_encode(['email' => 'a4abhi078@gmail.com', 'password' => 'Abhi@123']);
$ch = curl_init('http://localhost/clg_magzine/api/auth/login.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
$response = curl_exec($ch);
curl_close($ch);
echo "Response: " . $response . "\n";
