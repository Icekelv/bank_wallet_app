<?php
// GET — market prices with recent history, the user's holdings and cash.
require __DIR__ . '/_init.php';

$user = require_user();
$uid = (int) $user['id'];

$assets = db_all('SELECT * FROM crypto_assets WHERE active = 1 ORDER BY sort_order, symbol');
$holdRows = db_all('SELECT symbol, amount, avg_cost FROM holdings WHERE user_id = ? AND amount > 0', array($uid));
$holdings = array();
foreach ($holdRows as $h) {
    $holdings[$h['symbol']] = $h;
}

$out = array();
$cryptoTotal = 0.0;
foreach ($assets as $a) {
    // Last 48 hours of prices as [unix_time, price] pairs for the charts.
    $hist = db_all(
        'SELECT price, UNIX_TIMESTAMP(created_at) t FROM price_history
         WHERE symbol = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 48 HOUR) ORDER BY id DESC LIMIT 600',
        array($a['symbol'])
    );
    $points = array();
    foreach (array_reverse($hist) as $p) {
        $points[] = array((int) $p['t'], (float) $p['price']);
    }
    $price = (float) $a['price'];
    // Always end the series on the current price.
    $points[] = array(time(), $price);
    $day = db_one(
        'SELECT MIN(price) lo, MAX(price) hi FROM price_history WHERE symbol = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY)',
        array($a['symbol'])
    );
    $amount = isset($holdings[$a['symbol']]) ? (float) $holdings[$a['symbol']]['amount'] : 0.0;
    $value = round($amount * $price, 2);
    $cryptoTotal += $value;
    $out[] = array(
        'symbol' => $a['symbol'],
        'name' => $a['name'],
        'price' => $price,
        'change_24h' => (float) $a['change_24h'],
        'high_24h' => $day && $day['hi'] !== null ? max((float) $day['hi'], $price) : $price,
        'low_24h' => $day && $day['lo'] !== null ? min((float) $day['lo'], $price) : $price,
        'history' => $points,
        'amount' => $amount,
        'avg_cost' => isset($holdings[$a['symbol']]) ? (float) $holdings[$a['symbol']]['avg_cost'] : 0.0,
        'value' => $value,
        'updated_at' => $a['updated_at'],
    );
}

json_out(array(
    'assets' => $out,
    'cash' => (float) $user['balance'],
    'crypto_total' => round($cryptoTotal, 2),
    'total' => round($cryptoTotal + (float) $user['balance'], 2),
));
