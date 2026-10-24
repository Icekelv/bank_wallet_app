<?php
// Admin panel bootstrap: session, login check, CSRF, page layout.

require_once __DIR__ . '/../includes/functions.php';

ini_set('display_errors', APP_DEBUG ? '1' : '0');
session_name('monofin_admin');
session_start(array('cookie_httponly' => true, 'cookie_samesite' => 'Lax'));

function admin_logged_in()
{
    return !empty($_SESSION['admin_id']);
}

function require_admin()
{
    if (!admin_logged_in()) {
        header('Location: index.php');
        exit;
    }
}

function csrf_token()
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
    }
    return $_SESSION['csrf'];
}

function csrf_field()
{
    return '<input type="hidden" name="csrf" value="' . csrf_token() . '">';
}

function check_csrf()
{
    if (!isset($_POST['csrf']) || !hash_equals(csrf_token(), (string) $_POST['csrf'])) {
        http_response_code(400);
        exit('Session expired. Go back and try again.');
    }
}

function flash($msg, $type = 'ok')
{
    $_SESSION['flash'] = array('msg' => $msg, 'type' => $type);
}

function redirect($url)
{
    header('Location: ' . $url);
    exit;
}

function admin_header($title, $active = '')
{
    $nav = array(
        'dashboard.php' => 'Dashboard',
        'users.php' => 'Users',
        'notify.php' => 'Notifications',
        'crypto.php' => 'Crypto prices',
        'settings.php' => 'Settings',
    );
    echo '<!doctype html><html lang="en"><head><meta charset="utf-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
    echo '<title>' . h($title) . ' · Admin</title><link rel="stylesheet" href="assets/admin.css"></head><body>';
    echo '<header class="top"><div class="wrap topbar"><a class="brand" href="dashboard.php">' . h(get_setting('bank_name', 'Admin')) . ' <span>admin</span></a><nav>';
    foreach ($nav as $file => $label) {
        $cls = $active === $file ? ' class="on"' : '';
        echo '<a href="' . $file . '"' . $cls . '>' . h($label) . '</a>';
    }
    echo '<a href="logout.php">Log out</a></nav></div></header><main class="wrap">';
    if (!empty($_SESSION['flash'])) {
        $f = $_SESSION['flash'];
        unset($_SESSION['flash']);
        echo '<div class="flash ' . h($f['type']) . '">' . h($f['msg']) . '</div>';
    }
    echo '<h1>' . h($title) . '</h1>';
}

function admin_footer()
{
    echo '</main></body></html>';
}

// Short readable result line for a push attempt.
function push_result_text($r)
{
    if (!fcm_is_configured()) {
        return 'Push skipped: Firebase service account not uploaded yet.';
    }
    if (isset($r['devices'])) {
        if ($r['devices'] === 0) {
            return 'User has no registered devices yet.';
        }
        return 'Push sent to ' . $r['sent'] . ' of ' . $r['devices'] . ' device(s)' . ($r['error'] ? ' (' . $r['error'] . ')' : '') . '.';
    }
    return $r['ok'] ? 'Push sent.' : 'Push failed: ' . $r['error'];
}
