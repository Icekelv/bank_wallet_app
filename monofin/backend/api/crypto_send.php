<?php
// POST symbol, quantity, recipient (email or account number) — send coins to another user.
require __DIR__ . '/_init.php';
require_post();

$user = require_user();
$uid = (int) $user['id'];
$symbol = strtoupper((string) input('symbol', ''));
$qtyIn = input('quantity');
if (!is_numeric($qtyIn) || (float) $qtyIn <= 0) {
    json_error('Enter a valid quantity.');
}
$qty = round((float) $qtyIn, 8);

$asset = db_one('SELECT * FROM crypto_assets WHERE symbol = ? AND active = 1', array($symbol));
if (!$asset) {
    json_error('This asset is not available.');
}
$target = find_user_by_recipient((string) input('recipient', ''));
if (!$target || $target['status'] !== 'active') {
    json_error('Recipient not found.');
}
if ((int) $target['id'] === $uid) {
    json_error('You cannot send to yourself.');
}
$value = round($qty * (float) $asset['price'], 2);

db_begin();
try {
    $ids = array($uid, (int) $target['id']);
    sort($ids);
    db_all('SELECT id FROM users WHERE id IN (?, ?) ORDER BY id FOR UPDATE', $ids);
    $h = db_one('SELECT amount FROM holdings WHERE user_id = ? AND symbol = ? FOR UPDATE', array($uid, $symbol));
    if (!$h || (float) $h['amount'] + 0.00000001 < $qty) {
        throw new RuntimeException('You do not hold enough ' . $symbol . '.');
    }
    db_exec('UPDATE holdings SET amount = amount - ? WHERE user_id = ? AND symbol = ?', array(coin_str($qty), $uid, $symbol));
    // Recipient's average cost is set at today's price for the coins received.
    $rh = db_one('SELECT amount, avg_cost FROM holdings WHERE user_id = ? AND symbol = ? FOR UPDATE', array((int) $target['id'], $symbol));
    $rHeld = $rh ? (float) $rh['amount'] : 0.0;
    $rAvg = $rh ? (float) $rh['avg_cost'] : 0.0;
    $newAvg = (($rHeld * $rAvg) + $value) / ($rHeld + $qty);
    db_exec(
        'INSERT INTO holdings (user_id, symbol, amount, avg_cost) VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE amount = VALUES(amount), avg_cost = VALUES(avg_cost)',
        array((int) $target['id'], $symbol, coin_str($rHeld + $qty), money_str($newAvg))
    );
    add_transaction($uid, 'crypto_out', 'out', $value, array(
        'asset' => $symbol, 'asset_amount' => $qty, 'price' => $asset['price'],
        'counterparty' => $target['full_name'], 'description' => 'Sent ' . coin_str($qty) . ' ' . $symbol,
    ));
    add_transaction($target['id'], 'crypto_in', 'in', $value, array(
        'asset' => $symbol, 'asset_amount' => $qty, 'price' => $asset['price'],
        'counterparty' => $user['full_name'], 'description' => 'Received ' . coin_str($qty) . ' ' . $symbol,
    ));
    db_commit();
} catch (RuntimeException $e) {
    db_rollback();
    json_error($e->getMessage());
}

notify_user($target['id'], 'Crypto received', coin_str($qty) . ' ' . $symbol . ' from ' . $user['full_name'], array('type' => 'balance'));
json_out(array('symbol' => $symbol, 'quantity' => $qty, 'recipient' => mask_name($target['full_name'])));
