<?php
// GET [limit=30] [scope=all|cash|crypto]
require __DIR__ . '/_init.php';

$user = require_user();
$limit = max(1, min(200, (int) input('limit', 30)));
$scope = (string) input('scope', 'all');

$where = 'user_id = ?';
if ($scope === 'cash') {
    $where .= " AND type IN ('deposit','withdrawal','transfer_in','transfer_out')";
} elseif ($scope === 'crypto') {
    $where .= " AND type IN ('buy','sell','crypto_in','crypto_out')";
}

$rows = db_all("SELECT * FROM transactions WHERE $where ORDER BY id DESC LIMIT $limit", array((int) $user['id']));
json_out(array('transactions' => array_map('format_transaction', $rows)));
