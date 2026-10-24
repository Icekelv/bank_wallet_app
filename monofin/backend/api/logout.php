<?php
// POST [fcm_token] — ends this session and stops pushes to this device.
require __DIR__ . '/_init.php';
require_post();

$user = current_user();
if ($user) {
    db_exec('DELETE FROM api_tokens WHERE token = ?', array(bearer_token()));
    $fcm = (string) input('fcm_token', '');
    if ($fcm !== '') {
        db_exec('DELETE FROM fcm_tokens WHERE token = ? AND user_id = ?', array($fcm, (int) $user['id']));
    }
}
json_out();
