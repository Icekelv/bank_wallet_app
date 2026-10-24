<?php
// POST frozen=1|0 — freeze or unfreeze the virtual card.
require __DIR__ . '/_init.php';
require_post();

$user = require_user();
$frozen = in_array(input('frozen'), array(1, '1', true, 'true'), true) ? 1 : 0;
db_exec('UPDATE users SET card_frozen = ? WHERE id = ?', array($frozen, (int) $user['id']));
json_out(array('card_frozen' => (bool) $frozen));
