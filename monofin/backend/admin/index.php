<?php
// Admin sign-in. On first visit (no admins yet) it creates the first admin.
require __DIR__ . '/_init.php';

if (admin_logged_in()) {
    redirect('dashboard.php');
}

$firstRun = (int) db_value('SELECT COUNT(*) FROM admins') === 0;
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $username = trim((string) ($_POST['username'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');

    if ($firstRun) {
        if (strlen($username) < 3 || strlen($password) < 8) {
            $error = 'Use a username of 3+ characters and a password of 8+ characters.';
        } else {
            db_exec('INSERT INTO admins (username, password_hash) VALUES (?, ?)', array($username, password_hash($password, PASSWORD_DEFAULT)));
            session_regenerate_id(true);
            $_SESSION['admin_id'] = db_insert_id();
            redirect('dashboard.php');
        }
    } else {
        $a = db_one('SELECT * FROM admins WHERE username = ?', array($username));
        if ($a && password_verify($password, $a['password_hash'])) {
            session_regenerate_id(true);
            $_SESSION['admin_id'] = (int) $a['id'];
            redirect('dashboard.php');
        }
        $error = 'Wrong username or password.';
    }
}
?><!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Admin sign in</title><link rel="stylesheet" href="assets/admin.css"></head>
<body class="center">
<form method="post" class="card login">
  <h1><?= $firstRun ? 'Create the admin account' : 'Admin sign in' ?></h1>
  <?php if ($firstRun): ?><p class="muted">No admin exists yet. The account you create here is the only one that can open this panel.</p><?php endif; ?>
  <?php if ($error): ?><div class="flash err"><?= h($error) ?></div><?php endif; ?>
  <?= csrf_field() ?>
  <label>Username<input name="username" required autocomplete="username"></label>
  <label>Password<input type="password" name="password" required autocomplete="<?= $firstRun ? 'new-password' : 'current-password' ?>"></label>
  <button class="btn"><?= $firstRun ? 'Create and sign in' : 'Sign in' ?></button>
</form>
</body></html>
