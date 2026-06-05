<?php
$hash = '$2y$10$ziFj7unq5eERsiefMuzo8u5pBlMFigIYieSeAk5JWThl529qoagfC';
if (password_verify('Abhi@123', $hash)) {
    echo "MATCHES Abhi@123\n";
} else {
    echo "DOES NOT MATCH Abhi@123\n";
}

if (password_verify('Abhi@123 ', $hash)) {
    echo "MATCHES 'Abhi@123 '\n";
}
