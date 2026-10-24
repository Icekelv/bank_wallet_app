<?php
// Broadcast a push notification to every user.
require __DIR__ . '/_init.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    check_csrf();
    $title = trim((string) ($_POST['title'] ?? ''));
    $body = trim((string) ($_POST['body'] ?? ''));
    if ($title === '' || $body === '') {
        flash('Write a title and a message.', 'err');
    } else {
        $r = notify_all($title, $body, array('type' => 'message'));
        flash('Saved to every user\'s inbox. ' . push_result_text($r));
    }
    redirect('notify.php');
}

$sent = db_all('SELECT * FROM notifications WHERE user_id IS NULL ORDER BY id DESC LIMIT 30');

admin_header('Notifications', 'notify.php');
?>
<section class="card">
  <h2>Send to all users</h2>
  <p class="muted">Delivered as a push to every installed app and kept in each user's in-app inbox. To message one person, open them on the Users page.</p>
  <form method="post" class="stack">
    <?= csrf_field() ?>
    <label>Title<input name="title" maxlength="150" required></label>
    <label>Message<textarea name="body" maxlength="500" rows="3" required></textarea></label>
    <button class="btn">Send to everyone</button>
  </form>
</section>
<section class="card">
  <h2>Previous broadcasts</h2>
  <div class="tablewrap"><table>
    <tr><th>Date</th><th>Title</th><th>Message</th></tr>
    <?php foreach ($sent as $n): ?>
    <tr><td><?= h(date('M j, H:i', strtotime($n['created_at']))) ?></td><td><?= h($n['title']) ?></td><td><?= h($n['body']) ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$sent): ?><tr><td colspan="3" class="muted">Nothing sent yet.</td></tr><?php endif; ?>
  </table></div>
</section>
<?php admin_footer();
