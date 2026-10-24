<?php
// GET — the user's notifications plus broadcasts sent after they joined.
require __DIR__ . '/_init.php';

$user = require_user();
$rows = db_all(
    'SELECT id, title, body, created_at FROM notifications
     WHERE user_id = ? OR (user_id IS NULL AND created_at >= ?)
     ORDER BY id DESC LIMIT 50',
    array((int) $user['id'], $user['created_at'])
);
foreach ($rows as &$r) {
    $r['id'] = (int) $r['id'];
}
json_out(array('notifications' => $rows));
