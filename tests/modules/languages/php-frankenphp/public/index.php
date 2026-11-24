<?php

header('Content-Type: application/json');

echo json_encode([
    'sapi' => PHP_SAPI,
    'zts' => ZEND_THREAD_SAFE,
    'shmop' => extension_loaded('shmop'),
    'memory_limit' => ini_get('memory_limit'),
]);
