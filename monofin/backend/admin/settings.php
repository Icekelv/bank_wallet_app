<?php
// App names, currency, sign-up, deposit text, admin password, push test.
require __DIR__ . '/_init.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $action = $_POST['action'] ?? '';
    if ($action === 'general') {
        set_setting('bank_name', trim((string) $_POST['bank_name']) ?: 'Bank');
        set_setting('wallet_name', trim((string) $_POST['wallet_name']) ?: 'Wallet');
        set_setting('currency_symbol', trim((string) $_POST['currency_symbol']) ?: '$');
        set_setting('price_currency', strtolower(preg_replace('/[^A-Za-z]/', '', (string) $_POST['price_currency'])) ?: 'usd');
        set_setting('deposit_instructions', trim((string) $_POST['deposit_instructions']));
        set_setting('signup_enabled', isset($_POST['signup_enabled']) ? '1' : '0');
        push_config_refresh();
        flash('Settings saved.');
    } elseif ($action === 'admin_password') {
        $a = db_one('SELECT * FROM admins WHERE id = ?', array((int) $_SESSION['admin_id']));
        if (!$a || !password_verify((string) $_POST['current'], $a['password_hash'])) {
            flash('Current password is wrong.', 'err');
        } elseif (strlen((string) $_POST['new']) < 8) {
            flash('New password must be 8+ characters.', 'err');
        } else {
            db_exec('UPDATE admins SET password_hash = ? WHERE id = ?', array(password_hash((string) $_POST['new'], PASSWORD_DEFAULT), (int) $a['id']));
            flash('Admin password changed.');
        }
    } elseif ($action === 'test_push') {
        $r = fcm_send_to_topic('all', 'Test notification', 'Push notifications are working.', array('type' => 'message'));
        flash(push_result_text($r), $r['ok'] ? 'ok' : 'err');
    }
    redirect('settings.php');
}

admin_header('Settings', 'settings.php');
?>
<div class="grid2">
<section class="card">
  <h2>General</h2>
  <form method="post" class="stack">
    <?= csrf_field() ?><input type="hidden" name="action" value="general">
    <div class="row">
      <label>Bank app name<input name="bank_name" value="<?= h(get_setting('bank_name')) ?>"></label>
      <label>Wallet app name<input name="wallet_name" value="<?= h(get_setting('wallet_name')) ?>"></label>
    </div>
    <div class="row">
      <label>Currency symbol<input name="currency_symbol" value="<?= h(get_setting('currency_symbol', '$')) ?>" maxlength="4"></label>
      <label>Crypto price currency<input name="price_currency" value="<?= h(get_setting('price_currency', 'usd')) ?>" maxlength="5" placeholder="usd, ngn, eur"></label>
    </div>
    <label>How to fund an account (shown on “Top up”)<textarea name="deposit_instructions" rows="4"><?= h(get_setting('deposit_instructions')) ?></textarea></label>
    <label class="check"><input type="checkbox" name="signup_enabled" value="1" <?= get_setting('signup_enabled', '1') === '1' ? 'checked' : '' ?>> Allow new sign-ups in the app</label>
    <button class="btn">Save settings</button>
  </form>
</section>

<div>
<section class="card">
  <h2>Push notifications</h2>
  <?php if (fcm_is_configured()): ?>
    <p>Firebase project: <strong><?= h(fcm_service_account()['project_id']) ?></strong></p>
    <form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="test_push"><button class="btn ghost">Send test push to all</button></form>
  <?php else: ?>
    <p class="muted">Not configured. In Firebase console open Project settings › Service accounts › Generate new private key, rename the file to <code>firebase-service-account.json</code> and upload it next to <code>config.php</code>.</p>
  <?php endif; ?>
</section>

<section class="card">
  <h2>Admin password</h2>
  <form method="post" class="stack">
    <?= csrf_field() ?><input type="hidden" name="action" value="admin_password">
    <label>Current password<input type="password" name="current" required autocomplete="current-password"></label>
    <label>New password<input type="password" name="new" minlength="8" required autocomplete="new-password"></label>
    <button class="btn ghost">Change password</button>
  </form>
</section>
</div>
</div>
<?php admin_footer();
