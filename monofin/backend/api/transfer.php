<?php
// POST recipient (account number or email), amount, [note]
require __DIR__ . '/_init.php';
require_post();

$user = require_user();
$amount = parse_amount(input('amount'));
$note = mb_substr((string) input('note', ''), 0, 120);
$target = find_user_by_recipient((string) input('recipient', ''));

if (!$target || $target['status'] !== 'active') {
    json_error('Recipient account not found.');
}
if ((int) $target['id'] === (int) $user['id']) {
    json_error('You cannot send money to yourself.');
}

db_begin();
try {
    // Lock both rows in id order so two opposite transfers cannot deadlock.
    $ids = array((int) $user['id'], (int) $target['id']);
    sort($ids);
    db_all('SELECT id FROM users WHERE id IN (?, ?) ORDER BY id FOR UPDATE', $ids);

    $balance = (float) db_value('SELECT balance FROM users WHERE id = ?', array((int) $user['id']));
    if ($balance < $amount) {
        throw new RuntimeException('Insufficient balance.');
    }
    db_exec('UPDATE users SET balance = balance - ? WHERE id = ?', array(money_str($amount), (int) $user['id']));
    db_exec('UPDATE users SET balance = balance + ? WHERE id = ?', array(money_str($amount), (int) $target['id']));

    $senderBal = (float) db_value('SELECT balance FROM users WHERE id = ?', array((int) $user['id']));
    $recvBal = (float) db_value('SELECT balance FROM users WHERE id = ?', array((int) $target['id']));

    $txId = add_transaction($user['id'], 'transfer_out', 'out', $amount, array(
        'counterparty' => $target['full_name'],
        'description' => $note !== '' ? $note : 'Transfer to ' . $target['full_name'],
        'balance_after' => $senderBal,
    ));
    add_transaction($target['id'], 'transfer_in', 'in', $amount, array(
        'counterparty' => $user['full_name'],
        'description' => $note !== '' ? $note : 'Transfer from ' . $user['full_name'],
        'balance_after' => $recvBal,
    ));
    db_commit();
} catch (RuntimeException $e) {
    db_rollback();
    json_error($e->getMessage());
}

notify_user($target['id'], 'Money received', money_fmt($amount) . ' from ' . $user['full_name'] . ($note !== '' ? ' · ' . $note : ''), array('type' => 'balance'));

json_out(array(
    'transaction_id' => $txId,
    'balance' => $senderBal,
    'recipient' => mask_name($target['full_name']),
));
