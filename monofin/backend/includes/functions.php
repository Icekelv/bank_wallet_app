<?php
// Shared helpers: settings, users, ledger, notifications.

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/fcm.php';

// ---------- settings ----------

function get_setting($key, $default = '')
{
    static $cache = null;
    if ($cache === null) {
        $cache = array();
        foreach (db_all('SELECT skey, svalue FROM settings') as $r) {
            $cache[$r['skey']] = $r['svalue'];
        }
    }
    return array_key_exists($key, $cache) ? $cache[$key] : $default;
}

function set_setting($key, $value)
{
    db_exec(
        'INSERT INTO settings (skey, svalue) VALUES (?, ?) ON DUPLICATE KEY UPDATE svalue = VALUES(svalue)',
        array($key, (string) $value)
    );
}

// The experience a user sees: their personal override, else the global mode.
function effective_mode($user = null)
{
    if ($user && in_array($user['mode_override'], array('bank', 'wallet'), true)) {
        return $user['mode_override'];
    }
    $mode = get_setting('app_mode', 'bank');
    return $mode === 'wallet' ? 'wallet' : 'bank';
}

// ---------- formatting ----------

function money_str($n)
{
    return number_format((float) $n, 2, '.', '');
}

function coin_str($n)
{
    return rtrim(rtrim(number_format((float) $n, 8, '.', ''), '0'), '.');
}

function money_fmt($n)
{
    return get_setting('currency_symbol', '$') . number_format((float) $n, 2);
}

function h($s)
{
    return htmlspecialchars((string) $s, ENT_QUOTES, 'UTF-8');
}

// ---------- users ----------

function generate_account_number()
{
    do {
        $num = (string) random_int(1, 9);
        for ($i = 0; $i < 9; $i++) {
            $num .= (string) random_int(0, 9);
        }
    } while (db_value('SELECT id FROM users WHERE account_number = ?', array($num)));
    return $num;
}

function find_user_by_recipient($q)
{
    $q = trim($q);
    if ($q === '') {
        return null;
    }
    if (strpos($q, '@') !== false) {
        return db_one('SELECT * FROM users WHERE email = ?', array(strtolower($q)));
    }
    return db_one('SELECT * FROM users WHERE account_number = ?', array(preg_replace('/\D/', '', $q)));
}

function public_user($u)
{
    return array(
        'id' => (int) $u['id'],
        'full_name' => $u['full_name'],
        'email' => $u['email'],
        'phone' => $u['phone'],
        'account_number' => $u['account_number'],
        'balance' => (float) $u['balance'],
        'card_last4' => $u['card_last4'],
        'card_expiry' => $u['card_expiry'],
        'card_frozen' => (bool) $u['card_frozen'],
        'mode' => effective_mode($u),
        'created_at' => $u['created_at'],
    );
}

function mask_name($name)
{
    $parts = preg_split('/\s+/', trim($name));
    $out = array();
    foreach ($parts as $i => $p) {
        $out[] = $i === 0 ? $p : mb_substr($p, 0, 1) . '.';
    }
    return implode(' ', $out);
}

// ---------- ledger ----------

function add_transaction($user_id, $type, $direction, $amount, $opts = array())
{
    db_exec(
        'INSERT INTO transactions (user_id, type, direction, amount, asset, asset_amount, price, counterparty, description, balance_after)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        array(
            (int) $user_id,
            $type,
            $direction,
            money_str($amount),
            isset($opts['asset']) ? $opts['asset'] : 'USD',
            isset($opts['asset_amount']) ? coin_str($opts['asset_amount']) : null,
            isset($opts['price']) ? money_str($opts['price']) : null,
            isset($opts['counterparty']) ? $opts['counterparty'] : null,
            isset($opts['description']) ? $opts['description'] : null,
            isset($opts['balance_after']) ? money_str($opts['balance_after']) : null,
        )
    );
    return db_insert_id();
}

function format_transaction($t)
{
    return array(
        'id' => (int) $t['id'],
        'type' => $t['type'],
        'direction' => $t['direction'],
        'amount' => (float) $t['amount'],
        'asset' => $t['asset'],
        'asset_amount' => $t['asset_amount'] === null ? null : (float) $t['asset_amount'],
        'price' => $t['price'] === null ? null : (float) $t['price'],
        'counterparty' => $t['counterparty'],
        'description' => $t['description'],
        'balance_after' => $t['balance_after'] === null ? null : (float) $t['balance_after'],
        'created_at' => $t['created_at'],
    );
}

// Credit or debit a user's cash balance from the admin panel.
function admin_adjust_balance($user_id, $amount, $direction, $description)
{
    db_begin();
    try {
        $u = db_one('SELECT * FROM users WHERE id = ? FOR UPDATE', array((int) $user_id));
        if (!$u) {
            throw new RuntimeException('User not found.');
        }
        if ($direction === 'out' && (float) $u['balance'] < $amount) {
            throw new RuntimeException('Balance is lower than the debit amount.');
        }
        $sql = $direction === 'in'
            ? 'UPDATE users SET balance = balance + ? WHERE id = ?'
            : 'UPDATE users SET balance = balance - ? WHERE id = ?';
        db_exec($sql, array(money_str($amount), (int) $user_id));
        $bal = (float) db_value('SELECT balance FROM users WHERE id = ?', array((int) $user_id));
        add_transaction($user_id, $direction === 'in' ? 'deposit' : 'withdrawal', $direction, $amount, array(
            'description' => $description,
            'balance_after' => $bal,
        ));
        db_commit();
    } catch (Exception $e) {
        db_rollback();
        throw $e;
    }
    $title = $direction === 'in' ? 'Account credited' : 'Account debited';
    notify_user($user_id, $title, money_fmt($amount) . ' · ' . $description . '. New balance ' . money_fmt($bal), array('type' => 'balance'));
    return $bal;
}

// ---------- notifications ----------

// Stores the notification for the in-app list and sends a push.
function notify_user($user_id, $title, $body, $data = array())
{
    db_exec('INSERT INTO notifications (user_id, title, body) VALUES (?, ?, ?)', array((int) $user_id, $title, $body));
    return fcm_send_to_user($user_id, $title, $body, $data);
}

function notify_all($title, $body, $data = array())
{
    db_exec('INSERT INTO notifications (user_id, title, body) VALUES (NULL, ?, ?)', array($title, $body));
    return fcm_send_to_topic('all', $title, $body, $data);
}

// Silent push telling apps to reload their configuration (mode switch).
function push_config_refresh($user_id = null)
{
    if ($user_id === null) {
        return fcm_send_to_topic('all', null, null, array('type' => 'config'));
    }
    return fcm_send_to_user($user_id, null, null, array('type' => 'config'));
}

// ---------- crypto ----------

function record_price($symbol, $price, $change = null)
{
    if ($change === null) {
        db_exec('UPDATE crypto_assets SET price = ?, updated_at = NOW() WHERE symbol = ?', array(money_str($price), $symbol));
    } else {
        db_exec(
            'UPDATE crypto_assets SET price = ?, change_24h = ?, updated_at = NOW() WHERE symbol = ?',
            array(money_str($price), number_format((float) $change, 2, '.', ''), $symbol)
        );
    }
    db_exec('INSERT INTO price_history (symbol, price) VALUES (?, ?)', array($symbol, money_str($price)));
}

// Pulls live prices from CoinGecko's public API. Returns number of assets updated.
function sync_prices_from_coingecko()
{
    $assets = db_all('SELECT symbol, coingecko_id FROM crypto_assets WHERE active = 1 AND coingecko_id IS NOT NULL AND coingecko_id <> ""');
    if (!$assets) {
        return 0;
    }
    $ids = array();
    foreach ($assets as $a) {
        $ids[] = $a['coingecko_id'];
    }
    // Prices are kept in the same currency as user balances (setting: price_currency, e.g. usd, ngn, eur).
    $cur = strtolower(get_setting('price_currency', 'usd'));
    $url = 'https://api.coingecko.com/api/v3/simple/price?vs_currencies=' . urlencode($cur) . '&include_24hr_change=true&ids=' . urlencode(implode(',', $ids));
    $ch = curl_init($url);
    curl_setopt_array($ch, array(
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_HTTPHEADER => array('Accept: application/json', 'User-Agent: monofin/1.0'),
    ));
    $raw = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($raw === false || $code !== 200) {
        throw new RuntimeException('CoinGecko request failed (HTTP ' . $code . ').');
    }
    $data = json_decode($raw, true);
    $n = 0;
    foreach ($assets as $a) {
        $id = $a['coingecko_id'];
        if (isset($data[$id][$cur])) {
            $chg = isset($data[$id][$cur . '_24h_change']) ? $data[$id][$cur . '_24h_change'] : 0;
            record_price($a['symbol'], $data[$id][$cur], $chg);
            $n++;
        }
    }
    return $n;
}
