<?php

header('Content-Type: application/json');

echo json_encode([
    'sapi' => PHP_SAPI,
    'host' => $_SERVER['HTTP_HOST'] ?? null,
]);
