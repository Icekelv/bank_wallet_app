<?php
// Firebase Cloud Messaging (HTTP v1) in plain procedural PHP — no Composer needed.
// Needs the openssl and curl PHP extensions, and the service account JSON file
// whose path is set in config.php.

require_once __DIR__ . '/db.php';

function fcm_service_account()
{
    static $sa = null;
    if ($sa === null) {
        if (!is_readable(FCM_SERVICE_ACCOUNT_FILE)) {
            $sa = false;
        } else {
            $sa = json_decode(file_get_contents(FCM_SERVICE_ACCOUNT_FILE), true);
            if (!is_array($sa) || empty($sa['private_key']) || empty($sa['client_email']) || empty($sa['project_id'])) {
                $sa = false;
            }
        }
    }
    return $sa;
}

function fcm_is_configured()
{
    return fcm_service_account() !== false;
}

function fcm_b64url($data)
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

// OAuth2 access token, cached in the settings table until it expires.
function fcm_access_token()
{
    $sa = fcm_service_account();
    if (!$sa) {
        return null;
    }
    $cached = db_one('SELECT svalue FROM settings WHERE skey = ?', array('fcm_access_token'));
    if ($cached) {
        $c = json_decode($cached['svalue'], true);
        if ($c && $c['expires'] > time() + 60) {
            return $c['token'];
        }
    }

    $now = time();
    $header = fcm_b64url(json_encode(array('alg' => 'RS256', 'typ' => 'JWT')));
    $claims = fcm_b64url(json_encode(array(
        'iss' => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    )));
    $signature = '';
    if (!openssl_sign($header . '.' . $claims, $signature, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
        return null;
    }
    $jwt = $header . '.' . $claims . '.' . fcm_b64url($signature);

    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, array(
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_POSTFIELDS => http_build_query(array(
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        )),
    ));
    $raw = curl_exec($ch);
    curl_close($ch);
    $res = json_decode((string) $raw, true);
    if (empty($res['access_token'])) {
        return null;
    }
    $store = json_encode(array('token' => $res['access_token'], 'expires' => $now + (int) $res['expires_in']));
    db_exec(
        'INSERT INTO settings (skey, svalue) VALUES (?, ?) ON DUPLICATE KEY UPDATE svalue = VALUES(svalue)',
        array('fcm_access_token', $store)
    );
    return $res['access_token'];
}

// Low-level send. $target is array('token' => ...) or array('topic' => ...).
// Pass $title = null for a silent data-only message.
// Returns array('ok' => bool, 'code' => http status, 'error' => string|null).
function fcm_send($target, $title, $body, $data = array())
{
    $sa = fcm_service_account();
    if (!$sa) {
        return array('ok' => false, 'code' => 0, 'error' => 'FCM is not configured (service account file missing or invalid).');
    }
    $access = fcm_access_token();
    if (!$access) {
        return array('ok' => false, 'code' => 0, 'error' => 'Could not get a Google access token. Check the service account file and that the server can reach oauth2.googleapis.com.');
    }

    $message = $target;
    // FCM data values must all be strings.
    $strData = array();
    foreach ($data as $k => $v) {
        $strData[(string) $k] = (string) $v;
    }
    if ($strData) {
        $message['data'] = $strData;
    }
    if ($title !== null) {
        $message['notification'] = array('title' => $title, 'body' => (string) $body);
        $message['android'] = array('priority' => 'HIGH', 'notification' => array('sound' => 'default'));
    } else {
        $message['android'] = array('priority' => 'HIGH');
    }

    $url = 'https://fcm.googleapis.com/v1/projects/' . $sa['project_id'] . '/messages:send';
    $ch = curl_init($url);
    curl_setopt_array($ch, array(
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_HTTPHEADER => array('Authorization: Bearer ' . $access, 'Content-Type: application/json'),
        CURLOPT_POSTFIELDS => json_encode(array('message' => $message)),
    ));
    $raw = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($code === 200) {
        return array('ok' => true, 'code' => 200, 'error' => null);
    }
    $err = json_decode((string) $raw, true);
    $msg = isset($err['error']['message']) ? $err['error']['message'] : 'HTTP ' . $code;
    return array('ok' => false, 'code' => $code, 'error' => $msg);
}

function fcm_send_to_topic($topic, $title, $body, $data = array())
{
    return fcm_send(array('topic' => $topic), $title, $body, $data);
}

// Sends to every device a user is signed in on; prunes dead tokens.
function fcm_send_to_user($user_id, $title, $body, $data = array())
{
    $tokens = db_all('SELECT id, token FROM fcm_tokens WHERE user_id = ?', array((int) $user_id));
    $sent = 0;
    $lastError = null;
    foreach ($tokens as $t) {
        $r = fcm_send(array('token' => $t['token']), $title, $body, $data);
        if ($r['ok']) {
            $sent++;
        } else {
            $lastError = $r['error'];
            if ($r['code'] === 404 || ($r['code'] === 400 && stripos((string) $r['error'], 'registration token') !== false)) {
                db_exec('DELETE FROM fcm_tokens WHERE id = ?', array((int) $t['id']));
            }
        }
    }
    return array('ok' => $sent > 0, 'sent' => $sent, 'devices' => count($tokens), 'error' => $lastError);
}
