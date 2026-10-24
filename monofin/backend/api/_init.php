<?php
// Common bootstrap for every API endpoint.

require_once __DIR__ . '/../includes/functions.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type, X-Auth-Token');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

ini_set('display_errors', APP_DEBUG ? '1' : '0');

set_exception_handler(function ($e) {
    http_response_code(500);
    $msg = APP_DEBUG ? $e->getMessage() : 'Server error. Please try again.';
    echo json_encode(array('ok' => false, 'error' => $msg));
});

function json_out($data = array())
{
    echo json_encode(array('ok' => true) + $data);
    exit;
}

function json_error($message, $status = 400)
{
    http_response_code($status);
    echo json_encode(array('ok' => false, 'error' => $message));
    exit;
}

function require_post()
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        json_error('Use POST for this endpoint.', 405);
    }
}

// Reads a field from a JSON body, form post or query string.
function input($key, $default = null)
{
    static $body = null;
    if ($body === null) {
        $body = array();
        $raw = file_get_contents('php://input');
        if ($raw !== '' && $raw !== false) {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                $body = $decoded;
            }
        }
    }
    if (array_key_exists($key, $body)) {
        return is_string($body[$key]) ? trim($body[$key]) : $body[$key];
    }
    if (isset($_POST[$key])) {
        return trim($_POST[$key]);
    }
    if (isset($_GET[$key])) {
        return trim($_GET[$key]);
    }
    return $default;
}

function bearer_token()
{
    $h = '';
    if (!empty($_SERVER['HTTP_AUTHORIZATION'])) {
        $h = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (!empty($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $h = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    } elseif (function_exists('apache_request_headers')) {
        $all = apache_request_headers();
        foreach ($all as $k => $v) {
            if (strtolower($k) === 'authorization') {
                $h = $v;
            }
        }
    }
    if (stripos($h, 'Bearer ') === 0) {
        return trim(substr($h, 7));
    }
    // Some shared hosts strip Authorization; the app also sends X-Auth-Token.
    if (!empty($_SERVER['HTTP_X_AUTH_TOKEN'])) {
        return trim($_SERVER['HTTP_X_AUTH_TOKEN']);
    }
    return '';
}

function current_user()
{
    $token = bearer_token();
    if (strlen($token) !== 64) {
        return null;
    }
    $u = db_one(
        'SELECT u.* FROM api_tokens t JOIN users u ON u.id = t.user_id WHERE t.token = ?',
        array($token)
    );
    if ($u) {
        db_exec('UPDATE api_tokens SET last_used = NOW() WHERE token = ?', array($token));
    }
    return $u;
}

function require_user()
{
    $u = current_user();
    if (!$u) {
        json_error('Please sign in again.', 401);
    }
    if ($u['status'] !== 'active') {
        json_error('This account is suspended. Contact support.', 403);
    }
    return $u;
}

function issue_token($user_id)
{
    $token = bin2hex(random_bytes(32));
    db_exec('INSERT INTO api_tokens (user_id, token) VALUES (?, ?)', array((int) $user_id, $token));
    return $token;
}

function parse_amount($value)
{
    if (!is_numeric($value)) {
        json_error('Enter a valid amount.');
    }
    $n = round((float) $value, 2);
    if ($n <= 0) {
        json_error('Amount must be greater than zero.');
    }
    return $n;
}
