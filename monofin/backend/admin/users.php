<?php
// Users list with search.
require __DIR__ . '/_init.php';
require_admin();

$q = trim((string) ($_GET['q'] ?? ''));
if ($q !== '') {
    $like = '%' . $q . '%';
    $users = db_all(
        'SELECT * FROM users WHERE full_name LIKE ? OR email LIKE ? OR account_number LIKE ? ORDER BY id DESC LIMIT 200',
        array($like, $like, $like)
    );
} else {
    $users = db_all('SELECT * FROM users ORDER BY id DESC LIMIT 200');
}
$global = get_setting('app_mode', 'bank');

admin_header('Users', 'users.php');
?>
<form method="get" class="search">
  <input name="q" value="<?= h($q) ?>" placeholder="Search name, email or account number" aria-label="Search users">
  <button class="btn">Search</button>
</form>
<section class="card">
  <div class="tablewrap"><table>
    <tr><th>Name</th><th>Email</th><th>Account</th><th class="r">Balance</th><th>Sees</th><th>Status</th><th></th></tr>
    <?php foreach ($users as $u): ?>
    <tr>
      <td><?= h($u['full_name']) ?></td>
      <td><?= h($u['email']) ?></td>
      <td><?= h($u['account_number']) ?></td>
      <td class="r"><?= h(money_fmt($u['balance'])) ?></td>
      <td><?= h(ucfirst(effective_mode($u))) ?><?= $u['mode_override'] ? ' <span class="pill">override</span>' : '' ?></td>
      <td><?= $u['status'] === 'active' ? 'Active' : '<span class="pill warn">Suspended</span>' ?></td>
      <td class="r"><a class="btn small ghost" href="user.php?id=<?= (int) $u['id'] ?>">Manage</a></td>
    </tr>
    <?php endforeach; ?>
    <?php if (!$users): ?><tr><td colspan="7" class="muted">No users found.</td></tr><?php endif; ?>
  </table></div>
</section>
<p class="muted">Global mode is <strong><?= h(ucfirst($global)) ?></strong>.</p>
<?php admin_footer();
