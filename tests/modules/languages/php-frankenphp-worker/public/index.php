<?php

// Booted once per worker: the ID stays the same across requests until the worker restarts.
$worker = bin2hex(random_bytes(8));

$handler = static function () use ($worker): void {
    header('Content-Type: application/json');

    echo json_encode([
        'worker' => $worker,
        'message' => 'original',
    ]);
};

while (frankenphp_handle_request($handler)) {
    gc_collect_cycles();
}
