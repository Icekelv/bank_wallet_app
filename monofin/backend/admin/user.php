<?php
// One user: mode override, fund/debit, suspend, push, history.
require __DIR__ . '/_init.php';
require_admin();

$id = (int) ($_GET['id'] ?? 0);
$u = db_one('SELECT * FROM users WHERE id = ?', array($id));
if (!$u) {
    flash('User not found.', 'err');
    redirect('users.php');
}
$self = 'user.php?id=' . $id;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = $_POST['action'] ?? '';

    if ($action === 'mode') {
        $m = $_POST['mode_override'] ?? '';
        $val = in_array($m, array('bank', 'wallet'), true) ? $m : null;
        db_exec('UPDATE users SET mode_override = ? WHERE id = ?', array($val, $id));
        $r = push_config_refresh($id);
        flash('Mode updated. ' . push_result_text($r));
    } elseif ($action === 'balance') {
        $amount = round((float) ($_POST['amount'] ?? 0), 2);
        $dir = ($_POST['direction'] ?? '') === 'out' ? 'out' : 'in';
        $desc = trim((string) ($_POST['description'] ?? '')) ?: ($dir === 'in' ? 'Deposit' : 'Withdrawal');
        if ($amount <= 0) {
            flash('Enter an amount above zero.', 'err');
        } else {
            try {
                $bal = admin_adjust_balance($id, $amount, $dir, $desc);
                flash(($dir === 'in' ? 'Credited ' : 'Debited ') . money_fmt($amount) . '. New balance ' . money_fmt($bal) . '.');
            } catch (RuntimeException $e) {
                flash($e->getMessage(), 'err');
            }
        }
    } elseif ($action === 'status') {
        $new = $u['status'] === 'active' ? 'suspended' : 'active';
        db_exec('UPDATE users SET status = ? WHERE id = ?', array($new, $id));
        if ($new === 'suspended') {
            db_exec('DELETE FROM api_tokens WHERE user_id = ?', array($id));
        }
        flash($new === 'active' ? 'Account re-activated.' : 'Account suspended and signed out.');
    } elseif ($action === 'push') {
        $title = trim((string) ($_POST['title'] ?? ''));
        $body = trim((string) ($_POST['body'] ?? ''));
        if ($title === '' || $body === '') {
            flash('Write a title and a message.', 'err');
        } else {
            $r = notify_user($id, $title, $body, array('type' => 'message'));
            flash('Saved to the user\'s inbox. ' . push_result_text($r));
        }
    } elseif ($action === 'password') {
        $pw = (string) ($_POST['new_password'] ?? '');
        if (strlen($pw) < 6) {
            flash('Password must be at least 6 characters.', 'err');
        } else {
            db_exec('UPDATE users SET password_hash = ? WHERE id = ?', array(password_hash($pw, PASSWORD_DEFAULT), $id));
            db_exec('DELETE FROM api_tokens WHERE user_id = ?', array($id));
            flash('Password changed. The user has been signed out on all devices.');
        }
    }
    redirect($self);
}

$tx = db_all('SELECT * FROM transactions WHERE user_id = ? ORDER BY id DESC LIMIT 50', array($id));
$holdings = db_all('SELECT h.*, a.price FROM holdings h JOIN crypto_assets a ON a.symbol = h.symbol WHERE h.user_id = ? AND h.amount > 0', array($id));
$devices = (int) db_value('SELECT COUNT(*) FROM fcm_tokens WHERE user_id = ?', array($id));

admin_header($u['full_name'], 'users.php');
?>
<p class="muted"><?= h($u['email']) ?> · Account <?= h($u['account_number']) ?> · Joined <?= h(date('M j, Y', strtotime($u['created_at']))) ?> · <?= $devices ?> push device(s)</p>

<section class="grid4">
  <div class="card stat"><span>Cash balance</span><strong><?= h(money_fmt($u['balance'])) ?></strong></div>
  <div class="card stat"><span>Sees</span><strong><?= h(ucfirst(effective_mode($u))) ?></strong></div>
  <div class="card stat"><span>Card</span><strong>•••• <?= h($u['card_last4']) ?><?= $u['card_frozen'] ? ' (frozen)' : '' ?></strong></div>
  <div class="card stat"><span>Status</span><strong><?= h(ucfirst($u['status'])) ?></strong></div>
</section>

<div class="grid2">
  <section class="card">
    <h2>App mode for this user</h2>
    <form method="post" class="stack">
      <?= csrf_field() ?><input type="hidden" name="action" value="mode">
      <label>Show this user
        <select name="mode_override">
          <option value="" <?= $u['mode_override'] === null ? 'selected' : '' ?>>Follow global setting (<?= h(get_setting('app_mode', 'bank')) ?>)</option>
          <option value="bank" <?= $u['mode_override'] === 'bank' ? 'selected' : '' ?>>Always Bank app</option>
          <option value="wallet" <?= $u['mode_override'] === 'wallet' ? 'selected' : '' ?>>Always Wallet app</option>
        </select>
      </label>
      <button class="btn">Save</button>
    </form>
  </section>

  <section class="card">
    <h2>Credit or debit balance</h2>
    <form method="post" class="stack">
      <?= csrf_field() ?><input type="hidden" name="action" value="balance">
      <div class="row">
        <label>Type<select name="direction"><option value="in">Credit (deposit)</option><option value="out">Debit (withdrawal)</option></select></label>
        <label>Amount<input name="amount" type="number" step="0.01" min="0.01" required></label>
      </div>
      <label>Description<input name="description" placeholder="e.g. Bank deposit confirmed"></label>
      <button class="btn">Apply</button>
    </form>
  </section>

  <section class="card">
    <h2>Send a notification</h2>
    <form method="post" class="stack">
      <?= csrf_field() ?><input type="hidden" name="action" value="push">
      <label>Title<input name="title" maxlength="150" required></label>
      <label>Message<textarea name="body" maxlength="500" rows="3" required></textarea></label>
      <button class="btn">Send</button>
    </form>
  </section>

  <section class="card">
    <h2>Account</h2>
    <form method="post" class="stack">
      <?= csrf_field() ?><input type="hidden" name="action" value="password">
      <label>Set a new password<input name="new_password" type="text" minlength="6" required></label>
      <button class="btn ghost">Change password</button>
    </form>
    <form method="post" style="margin-top:12px">
      <?= csrf_field() ?><input type="hidden" name="action" value="status">
      <button class="btn <?= $u['status'] === 'active' ? 'danger' : '' ?>"><?= $u['status'] === 'active' ? 'Suspend account' : 'Re-activate account' ?></button>
    </form>
  </section>
</div>

<?php if ($holdings): ?>
<section class="card">
  <h2>Crypto holdings</h2>
  <div class="tablewrap"><table>
    <tr><th>Asset</th><th class="r">Quantity</th><th class="r">Avg. cost</th><th class="r">Value now</th></tr>
    <?php foreach ($holdings as $hd): ?>
    <tr><td><?= h($hd['symbol']) ?></td><td class="r"><?= h(coin_str($hd['amount'])) ?></td><td class="r"><?= h(money_fmt($hd['avg_cost'])) ?></td><td class="r"><?= h(money_fmt($hd['amount'] * $hd['price'])) ?></td></tr>
    <?php endforeach; ?>
  </table></div>
</section>
<?php endif; ?>

<section class="card">
  <h2>Transactions</h2>
  <div class="tablewrap"><table>
    <tr><th>Date</th><th>Type</th><th>Details</th><th class="r">Amount</th><th class="r">Balance after</th></tr>
    <?php foreach ($tx as $t): ?>
    <tr>
      <td><?= h(date('M j, H:i', strtotime($t['created_at']))) ?></td>
      <td><span class="pill"><?= h(str_replace('_', ' ', $t['type'])) ?></span></td>
      <td><?= h($t['description']) ?></td>
      <td class="r"><?= $t['direction'] === 'in' ? '+' : '−' ?><?= h(money_fmt($t['amount'])) ?></td>
      <td class="r"><?= $t['balance_after'] === null ? '—' : h(money_fmt($t['balance_after'])) ?></td>
    </tr>
    <?php endforeach; ?>
    <?php if (!$tx): ?><tr><td colspan="5" class="muted">No transactions yet.</td></tr><?php endif; ?>
  </table></div>
</section>
<?php admin_footer();
