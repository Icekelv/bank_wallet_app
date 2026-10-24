<?php
// POST token — registers this device for push notifications.
require __DIR__ . '/_init.php';
require_post();

$user = require_user();
$token = (string) input('token', '');
if ($token === '' || strlen($token) > 255) {
    json_error('Missing device token.');
}
db_exec(
    'INSERT INTO fcm_tokens (user_id, token, updated_at) VALUES (?, ?, NOW())
     ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), updated_at = NOW()',
    array((int) $user['id'], $token)
);
json_out();
