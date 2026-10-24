<?php
// GET — public app configuration. With a valid token, `mode` is that user's mode.
require __DIR__ . '/_init.php';

$user = current_user();
$mode = effective_mode($user);

json_out(array(
    'mode' => $mode,
    'app_name' => $mode === 'wallet' ? get_setting('wallet_name', 'Wallet') : get_setting('bank_name', 'Bank'),
    'bank_name' => get_setting('bank_name', 'Bank'),
    'wallet_name' => get_setting('wallet_name', 'Wallet'),
    'currency_symbol' => get_setting('currency_symbol', '$'),
    'signup_enabled' => get_setting('signup_enabled', '1') === '1',
    'deposit_instructions' => get_setting('deposit_instructions', ''),
    'signed_in' => $user !== null,
));
