<?php
// GET — the signed-in user's profile and balance.
require __DIR__ . '/_init.php';

$user = require_user();
json_out(array('user' => public_user($user)));
