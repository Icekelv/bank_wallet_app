<?php
// GET q=<account number or email> — shows whose account it is before sending.
require __DIR__ . '/_init.php';

$user = require_user();
$target = find_user_by_recipient((string) input('q', ''));
if (!$target || $target['status'] !== 'active') {
    json_error('No account found.', 404);
}
if ((int) $target['id'] === (int) $user['id']) {
    json_error('That is your own account.');
}
json_out(array(
    'name' => mask_name($target['full_name']),
    'account_number' => $target['account_number'],
));
