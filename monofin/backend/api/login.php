<?php
// POST email, password
require __DIR__ . '/_init.php';
require_post();

$email = strtolower((string) input('email', ''));
$password = (string) input('password', '');

$user = db_one('SELECT * FROM users WHERE email = ?', array($email));
if (!$user || !password_verify($password, $user['password_hash'])) {
    json_error('Incorrect email or password.', 401);
}
if ($user['status'] !== 'active') {
    json_error('This account is suspended. Contact support.', 403);
}

json_out(array('token' => issue_token($user['id']), 'user' => public_user($user)));
