<?php
// POST side=buy|sell, symbol, amount (cash value) — or for sell, all=1 to sell everything.
// Trades settle instantly at the current price against the user's cash balance.
require __DIR__ . '/_init.php';
require_post();

$user = require_user();
$uid = (int) $user['id'];
$side = (string) input('side', '');
$symbol = strtoupper((string) input('symbol', ''));
$sellAll = in_array(input('all'), array(1, '1', true, 'true'), true);

if ($side !== 'buy' && $side !== 'sell') {
    json_error('Choose buy or sell.');
}
$asset = db_one('SELECT * FROM crypto_assets WHERE symbol = ? AND active = 1', array($symbol));
if (!$asset || (float) $asset['price'] <= 0) {
    json_error('This asset is not available.');
}
$price = (float) $asset['price'];
$amount = $sellAll ? 0 : parse_amount(input('amount'));

db_begin();
try {
    $u = db_one('SELECT balance FROM users WHERE id = ? FOR UPDATE', array($uid));
    $h = db_one('SELECT amount, avg_cost FROM holdings WHERE user_id = ? AND symbol = ? FOR UPDATE', array($uid, $symbol));
    $held = $h ? (float) $h['amount'] : 0.0;
    $avg = $h ? (float) $h['avg_cost'] : 0.0;

    if ($side === 'buy') {
        if ((float) $u['balance'] < $amount) {
            throw new RuntimeException('Not enough cash for this purchase.');
        }
        $qty = round($amount / $price, 8);
        if ($qty <= 0) {
            throw new RuntimeException('Amount is too small.');
        }
        $newQty = $held + $qty;
        $newAvg = $newQty > 0 ? (($held * $avg) + $amount) / $newQty : $price;
        db_exec('UPDATE users SET balance = balance - ? WHERE id = ?', array(money_str($amount), $uid));
        db_exec(
            'INSERT INTO holdings (user_id, symbol, amount, avg_cost) VALUES (?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE amount = VALUES(amount), avg_cost = VALUES(avg_cost)',
            array($uid, $symbol, coin_str($newQty), money_str($newAvg))
        );
        $cashValue = $amount;
        $direction = 'in';
    } else {
        $qty = $sellAll ? $held : round($amount / $price, 8);
        if ($qty <= 0 || $qty > $held + 0.00000001) {
            throw new RuntimeException('You do not hold enough ' . $symbol . '.');
        }
        $qty = min($qty, $held);
        $cashValue = $sellAll ? round($qty * $price, 2) : $amount;
        $newQty = $held - $qty;
        db_exec('UPDATE users SET balance = balance + ? WHERE id = ?', array(money_str($cashValue), $uid));
        db_exec('UPDATE holdings SET amount = ? WHERE user_id = ? AND symbol = ?', array(coin_str($newQty), $uid, $symbol));
        $direction = 'out';
    }
    $bal = (float) db_value('SELECT balance FROM users WHERE id = ?', array($uid));
    add_transaction($uid, $side, $direction, $cashValue, array(
        'asset' => $symbol,
        'asset_amount' => $qty,
        'price' => $price,
        'description' => ($side === 'buy' ? 'Bought ' : 'Sold ') . coin_str($qty) . ' ' . $symbol,
        'balance_after' => $bal,
    ));
    db_commit();
} catch (RuntimeException $e) {
    db_rollback();
    json_error($e->getMessage());
}

json_out(array(
    'side' => $side,
    'symbol' => $symbol,
    'quantity' => (float) coin_str($qty),
    'price' => $price,
    'value' => $cashValue,
    'cash' => $bal,
    'holding' => (float) coin_str($newQty),
));
