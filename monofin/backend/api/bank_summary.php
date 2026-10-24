<?php
// GET — money out per day for the last 7 days, plus this month's in/out.
require __DIR__ . '/_init.php';

$user = require_user();
$uid = (int) $user['id'];

$rows = db_all(
    "SELECT DATE(created_at) d, SUM(amount) s FROM transactions
     WHERE user_id = ? AND direction = 'out' AND type IN ('transfer_out','withdrawal')
       AND created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
     GROUP BY DATE(created_at)",
    array($uid)
);
$byDay = array();
foreach ($rows as $r) {
    $byDay[$r['d']] = (float) $r['s'];
}
$week = array();
for ($i = 6; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-$i day"));
    $week[] = array('date' => $d, 'label' => substr(date('D', strtotime($d)), 0, 1), 'amount' => isset($byDay[$d]) ? $byDay[$d] : 0.0);
}

$month = db_one(
    "SELECT
       COALESCE(SUM(CASE WHEN direction = 'in'  AND type IN ('deposit','transfer_in') THEN amount END), 0) AS money_in,
       COALESCE(SUM(CASE WHEN direction = 'out' AND type IN ('withdrawal','transfer_out') THEN amount END), 0) AS money_out
     FROM transactions WHERE user_id = ? AND created_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01')",
    array($uid)
);

json_out(array(
    'week' => $week,
    'week_total' => array_sum(array_column($week, 'amount')),
    'month_in' => (float) $month['money_in'],
    'month_out' => (float) $month['money_out'],
));
