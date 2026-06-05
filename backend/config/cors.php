<?php
// ── Suppress PHP warnings from leaking into JSON responses ──────────────────
error_reporting(E_ALL);
ini_set('display_errors', '0');   // never output errors to response body
ini_set('log_errors', '1');       // log them to WAMP's error log instead

// ── CORS + JSON headers ──────────────────────────────────────────────────────
// Call this at the top of every API endpoint.
function setCorsHeaders(): void {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
    header('Content-Type: application/json; charset=utf-8');

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}
