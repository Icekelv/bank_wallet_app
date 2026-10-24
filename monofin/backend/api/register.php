<?php
// POST full_name, email, phone, password
require __DIR__ . '/_init.php';
require_post();

if (get_setting('signup_enabled', '1') !== '1') {
    json_error('Sign-up is currently closed.');
}

$name = (string) input('full_name', '');
$email = strtolower((string) input('email', ''));
$phone = (string) input('phone', '');
$password = (string) input('password', '');

if (mb_strlen($name) < 2) {
    json_error('Enter your full name.');
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_error('Enter a valid email address.');
}
if (strlen($password) < 6) {
    json_error('Password must be at least 6 characters.');
}
if (db_value('SELECT id FROM users WHERE email = ?', array($email))) {
    json_error('An account with this email already exists.');
}

$last4 = str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT);
$expiry = date('m/y', strtotime('+4 years'));

db_exec(
    'INSERT INTO users (full_name, email, phone, password_hash, account_number, card_last4, card_expiry) VALUES (?, ?, ?, ?, ?, ?, ?)',
    array($name, $email, $phone, password_hash($password, PASSWORD_DEFAULT), generate_account_number(), $last4, $expiry)
);
$id = db_insert_id();
db_exec('INSERT INTO notifications (user_id, title, body) VALUES (?, ?, ?)', array(
    $id,
    'Welcome, ' . explode(' ', $name)[0],
    'Your account is ready. Fund it to start sending money and trading.',
));

$user = db_one('SELECT * FROM users WHERE id = ?', array($id));
json_out(array('token' => issue_token($id), 'user' => public_user($user)));
