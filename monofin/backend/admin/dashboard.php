<?php
// Dashboard: the global Bank / Wallet switch, totals and latest activity.
require __DIR__ . '/_init.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['app_mode'])) {
    check_csrf();
    $mode = $_POST['app_mode'] === 'wallet' ? 'wallet' : 'bank';
    set_setting('app_mode', $mode);
    $r = push_config_refresh();
    $label = $mode === 'wallet' ? 'Wallet app' : 'Bank app';
    flash('Users now see the ' . $label . ' (except users with a personal override). ' . push_result_text($r));
    redirect('dashboard.php');
}

$mode = get_setting('app_mode', 'bank');
$stats = db_one(
    "SELECT COUNT(*) users, COALESCE(SUM(balance),0) cash,
            SUM(mode_override IS NOT NULL) overrides
     FROM users"
);
$txToday = (int) db_value('SELECT COUNT(*) FROM transactions WHERE created_at >= CURDATE()');
$devices = (int) db_value('SELECT COUNT(*) FROM fcm_tokens');
$recent = db_all(
    'SELECT t.*, u.full_name FROM transactions t JOIN users u ON u.id = t.user_id ORDER BY t.id DESC LIMIT 12'
);

admin_header('Dashboard', 'dashboard.php');
?>
<section class="card">
  <h2>What the app shows</h2>
  <p class="muted">Pick the experience every user sees. Open apps switch within seconds through a silent push; others switch next time they open. A user-level override on the Users page takes priority.</p>
  <form method="post" class="modes">
    <?= csrf_field() ?>
    <button name="app_mode" value="bank" class="mode <?= $mode === 'bank' ? 'active' : '' ?>">
      <strong>Bank app</strong><span>Balance, cards, transfers</span><?= $mode === 'bank' ? '<em>Live</em>' : '' ?>
    </button>
    <button name="app_mode" value="wallet" class="mode dark <?= $mode === 'wallet' ? 'active' : '' ?>">
      <strong>Wallet app</strong><span>Crypto portfolio, buy, sell, send</span><?= $mode === 'wallet' ? '<em>Live</em>' : '' ?>
    </button>
  </form>
</section>

<section class="grid4">
  <div class="card stat"><span>Users</span><strong><?= (int) $stats['users'] ?></strong></div>
  <div class="card stat"><span>Total cash held</span><strong><?= h(money_fmt($stats['cash'])) ?></strong></div>
  <div class="card stat"><span>Transactions today</span><strong><?= $txToday ?></strong></div>
  <div class="card stat"><span>Push devices</span><strong><?= $devices ?></strong></div>
</section>

<?php if (!fcm_is_configured()): ?>
<div class="flash err">Push notifications are off: upload <code>firebase-service-account.json</code> next to <code>config.php</code>.</div>
<?php endif; ?>

<section class="card">
  <h2>Latest transactions</h2>
  <div class="tablewrap"><table>
    <tr><th>Date</th><th>User</th><th>Type</th><th>Details</th><th class="r">Amount</th></tr>
    <?php foreach ($recent as $t): ?>
    <tr>
      <td><?= h(date('M j, H:i', strtotime($t['created_at']))) ?></td>
      <td><a href="user.php?id=<?= (int) $t['user_id'] ?>"><?= h($t['full_name']) ?></a></td>
      <td><span class="pill"><?= h(str_replace('_', ' ', $t['type'])) ?></span></td>
      <td><?= h($t['description']) ?></td>
      <td class="r"><?= $t['direction'] === 'in' ? '+' : '−' ?><?= h(money_fmt($t['amount'])) ?></td>
    </tr>
    <?php endforeach; ?>
    <?php if (!$recent): ?><tr><td colspan="5" class="muted">No transactions yet.</td></tr><?php endif; ?>
  </table></div>
</section>
<?php admin_footer();
